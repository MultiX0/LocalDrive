package app_test

import (
	"net/http"
	"testing"
)

// TestDeviceApprovalStateMachine walks the whole gate: a second device on an
// account that already has an approved one gets a narrow token that can only
// poll its own status, an already-approved device lets it in, and the waiting
// client picks up real tokens on its next poll.
func TestDeviceApprovalStateMachine(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	// a second account turns device approval on for the whole server
	h.invite(admin, "mom", "another long password")

	var settings jsonMap
	admin.mustDo(http.MethodGet, "/api/v1/server/settings", nil, &settings, http.StatusOK)
	if required, _ := settings["require_device_approval"].(bool); !required {
		t.Fatal("a second account should turn device approval on")
	}

	// the admin signs in from a new device
	second := h.anonymous()
	var pending jsonMap
	second.mustDo(http.MethodPost, "/api/v1/auth/login", jsonMap{
		"username": "owner", "password": "correct horse battery",
		"device_name": "New Phone", "platform": "test",
	}, &pending, http.StatusAccepted)

	if pending["status"] != "pending" {
		t.Fatalf("a new device should be held, got %v", pending["status"])
	}
	sessionID, _ := pending["session_id"].(string)
	second.AccessToken, _ = pending["access_token"].(string)
	if sessionID == "" || second.AccessToken == "" {
		t.Fatal("a pending device needs a session id and a narrow token to poll with")
	}

	// that token reaches its own status and nothing else
	second.mustDo(http.MethodGet, "/api/v1/auth/session/"+sessionID+"/status",
		nil, nil, http.StatusOK)
	second.mustDo(http.MethodGet, "/api/v1/me", nil, nil, http.StatusForbidden)
	second.mustDo(http.MethodGet, "/api/v1/nodes", nil, nil, http.StatusForbidden)
	second.mustDo(http.MethodPost, "/api/v1/nodes/folder",
		jsonMap{"name": "sneaky"}, nil, http.StatusForbidden)

	// the already-approved device sees it waiting and approves it
	var waiting struct {
		Devices []jsonMap `json:"devices"`
	}
	admin.mustDo(http.MethodGet, "/api/v1/devices/pending", nil, &waiting, http.StatusOK)
	if len(waiting.Devices) != 1 {
		t.Fatalf("expected one pending device, got %d", len(waiting.Devices))
	}
	if waiting.Devices[0]["device_name"] != "New Phone" {
		t.Fatalf("the pending row should name the device, got %v", waiting.Devices[0]["device_name"])
	}
	admin.mustDo(http.MethodPost, "/api/v1/devices/"+sessionID+"/approve", nil, nil, http.StatusNoContent)

	// the waiting client picks the real tokens up on its next poll
	var approved jsonMap
	second.mustDo(http.MethodGet, "/api/v1/auth/session/"+sessionID+"/status",
		nil, &approved, http.StatusOK)
	if approved["status"] != "active" {
		t.Fatalf("the session should be active after approval, got %v", approved["status"])
	}
	second.adopt(approved)
	if second.RefreshToken == "" {
		t.Fatal("an approved device should get a refresh token")
	}
	second.mustDo(http.MethodGet, "/api/v1/me", nil, nil, http.StatusOK)
	second.createFolder("", "From The New Phone")
}

func TestDeniedDeviceStaysOut(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	h.invite(admin, "mom", "another long password")

	second := h.anonymous()
	var pending jsonMap
	second.mustDo(http.MethodPost, "/api/v1/auth/login", jsonMap{
		"username": "owner", "password": "correct horse battery",
		"device_name": "Not Mine", "platform": "test",
	}, &pending, http.StatusAccepted)
	sessionID := pending["session_id"].(string)
	second.AccessToken = pending["access_token"].(string)

	admin.mustDo(http.MethodPost, "/api/v1/devices/"+sessionID+"/deny", nil, nil, http.StatusNoContent)

	// a denied device's token stops working entirely
	second.mustDo(http.MethodGet, "/api/v1/auth/session/"+sessionID+"/status",
		nil, nil, http.StatusUnauthorized)
	second.mustDo(http.MethodGet, "/api/v1/me", nil, nil, http.StatusForbidden)
}

func TestApprovalCanBeTurnedOffForASingleUserDeployment(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	h.invite(admin, "mom", "another long password")

	admin.mustDo(http.MethodPatch, "/api/v1/server/settings",
		jsonMap{"require_device_approval": false}, nil, http.StatusOK)

	second := h.anonymous()
	var out jsonMap
	second.mustDo(http.MethodPost, "/api/v1/auth/login", jsonMap{
		"username": "owner", "password": "correct horse battery",
		"device_name": "Another Laptop", "platform": "test",
	}, &out, http.StatusOK)
	second.adopt(out)
	second.mustDo(http.MethodGet, "/api/v1/me", nil, nil, http.StatusOK)
}

func TestOneDeviceCannotApproveAnotherAccountsDevice(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	member := h.invite(admin, "mom", "another long password")
	other := h.invite(admin, "sister", "yet another long password")

	// mom signs in from a second device
	pendingDevice := h.anonymous()
	var pending jsonMap
	pendingDevice.mustDo(http.MethodPost, "/api/v1/auth/login", jsonMap{
		"username": "mom", "password": "another long password",
		"device_name": "Mom Tablet", "platform": "test",
	}, &pending, http.StatusAccepted)
	sessionID := pending["session_id"].(string)

	// an unrelated member cannot let it in
	other.mustDo(http.MethodPost, "/api/v1/devices/"+sessionID+"/approve", nil, nil, http.StatusForbidden)
	// and does not even see it waiting
	var waiting struct {
		Devices []jsonMap `json:"devices"`
	}
	other.mustDo(http.MethodGet, "/api/v1/devices/pending", nil, &waiting, http.StatusOK)
	if len(waiting.Devices) != 0 {
		t.Fatal("a member should only ever see their own pending devices")
	}

	// the account's own approved device can, which is the self-service path
	member.mustDo(http.MethodPost, "/api/v1/devices/"+sessionID+"/approve", nil, nil, http.StatusNoContent)

	// and an admin can step in server wide as the fallback for someone stuck
	admin.mustDo(http.MethodGet, "/api/v1/admin/devices/pending", nil, &waiting, http.StatusOK)
}

func TestTemporaryPasswordBlocksEverythingUntilChanged(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	member := h.invite(admin, "mom", "another long password")

	// this test is about the temporary password gate, so the separate
	// device-approval gate is turned off to keep the two apart
	admin.mustDo(http.MethodPatch, "/api/v1/server/settings",
		jsonMap{"require_device_approval": false}, nil, http.StatusOK)

	var reset jsonMap
	admin.mustDo(http.MethodPost, "/api/v1/admin/users/"+member.UserID+"/reset-password",
		jsonMap{}, &reset, http.StatusOK)
	temporary, _ := reset["temporary_password"].(string)
	if temporary == "" {
		t.Fatal("the reset did not return a temporary password")
	}

	// the reset ended every session on that account
	member.mustDo(http.MethodGet, "/api/v1/me", nil, nil, http.StatusUnauthorized)

	locked := h.anonymous()
	var login jsonMap
	locked.mustDo(http.MethodPost, "/api/v1/auth/login", jsonMap{
		"username": "mom", "password": temporary,
		"device_name": "Member Phone", "platform": "test",
	}, &login, http.StatusOK)
	locked.adopt(login)

	if must, _ := login["user"].(map[string]any)["must_change_password"].(bool); !must {
		t.Fatal("the account should be flagged as needing a new password")
	}

	// reads still work, nothing else does
	locked.mustDo(http.MethodGet, "/api/v1/me", nil, nil, http.StatusOK)
	locked.mustDo(http.MethodPost, "/api/v1/nodes/folder",
		jsonMap{"name": "Blocked"}, nil, http.StatusForbidden)

	// the one write it can make is choosing a new password
	locked.mustDo(http.MethodPatch, "/api/v1/me/password",
		jsonMap{"current_password": temporary, "new_password": "a brand new password"},
		nil, http.StatusNoContent)

	after := h.anonymous()
	var relogin jsonMap
	after.mustDo(http.MethodPost, "/api/v1/auth/login", jsonMap{
		"username": "mom", "password": "a brand new password",
		"device_name": "Member Phone", "platform": "test",
	}, &relogin, http.StatusOK)
	after.adopt(relogin)
	after.createFolder("", "Working Again")
}

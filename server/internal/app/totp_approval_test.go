package app_test

import (
	"net/http"
	"testing"
	"time"

	"github.com/pquerna/otp/totp"
)

// A correct code from the enrolled authenticator answers the same question
// device approval asks, and it answers it without needing the old device. This
// matters most in the case approval handles worst: the first device is lost, so
// there is nothing left to approve from and the account is shut.
func TestTOTPLetsANewDeviceInWithoutApproval(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	// a second account is what turns device approval on for the server
	h.invite(admin, "mom", "another long password")

	var settings jsonMap
	admin.mustDo(http.MethodGet, "/api/v1/server/settings", nil, &settings, http.StatusOK)
	if required, _ := settings["require_device_approval"].(bool); !required {
		t.Fatal("a second account should turn device approval on")
	}

	// enrol the authenticator
	var enrollment jsonMap
	admin.mustDo(http.MethodPost, "/api/v1/auth/2fa/begin", nil, &enrollment, http.StatusOK)
	secret, _ := enrollment["secret"].(string)
	if secret == "" {
		t.Fatal("enrolment returned no secret")
	}
	code, err := totp.GenerateCode(secret, time.Now())
	if err != nil {
		t.Fatalf("generate code: %v", err)
	}
	admin.mustDo(http.MethodPost, "/api/v1/auth/2fa/verify", jsonMap{
		"code": code, "password": "correct horse battery",
	}, nil, http.StatusNoContent)

	// a brand new device signs in with the password and a fresh code
	fresh, err := totp.GenerateCode(secret, time.Now())
	if err != nil {
		t.Fatalf("generate code: %v", err)
	}
	device := h.anonymous()
	var result jsonMap
	device.mustDo(http.MethodPost, "/api/v1/auth/login", jsonMap{
		"username": "owner", "password": "correct horse battery",
		"totp_code": fresh, "device_name": "Replacement Phone", "platform": "test",
	}, &result, http.StatusOK)

	if result["status"] == "pending" {
		t.Fatal("a device that passed two-factor was still held for approval, " +
			"which locks the account out when the approving device is gone")
	}
	token, _ := result["access_token"].(string)
	if token == "" {
		t.Fatal("no access token, so the device did not actually get in")
	}

	// and it is a full session, not the narrow pending one
	device.AccessToken = token
	device.mustDo(http.MethodGet, "/api/v1/me", nil, nil, http.StatusOK)
	device.mustDo(http.MethodGet, "/api/v1/nodes", nil, nil, http.StatusOK)
}

// Without two-factor there is nothing else proving who this is, so approval is
// still the only check and has to keep working.
func TestWithoutTOTPANewDeviceIsStillHeld(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	h.invite(admin, "mom", "another long password")

	device := h.anonymous()
	var result jsonMap
	device.mustDo(http.MethodPost, "/api/v1/auth/login", jsonMap{
		"username": "owner", "password": "correct horse battery",
		"device_name": "New Phone", "platform": "test",
	}, &result, http.StatusAccepted)

	if result["status"] != "pending" {
		t.Fatalf("with no second factor a new device should be held, got %v", result["status"])
	}
}

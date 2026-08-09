package app_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"
)

func TestFirstRunSetupIsOneTimeOnly(t *testing.T) {
	h := newHarness(t)

	var status jsonMap
	h.anonymous().mustDo(http.MethodGet, "/api/v1/status", nil, &status, http.StatusOK)
	if setup, _ := status["setup_required"].(bool); !setup {
		t.Fatal("a fresh server must report that setup is required")
	}
	// the discovery-facing status says nothing about contents
	for _, leaked := range []string{"user_count", "file_count", "users", "files"} {
		if _, present := status[leaked]; present {
			t.Fatalf("/status leaked %q", leaked)
		}
	}

	admin := h.setupAdmin("owner", "correct horse battery")
	if admin.UserID == "" {
		t.Fatal("setup did not return the new account")
	}

	h.anonymous().mustDo(http.MethodGet, "/api/v1/status", nil, &status, http.StatusOK)
	if setup, _ := status["setup_required"].(bool); setup {
		t.Fatal("setup should be complete once an account exists")
	}

	// it refuses outright the moment a single user exists
	h.anonymous().mustDo(http.MethodPost, "/api/v1/setup", jsonMap{
		"username": "sneaky", "password": "another long password",
	}, nil, http.StatusConflict)
}

func TestRegistrationNeedsAnInviteByDefault(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	// self registration is off, so a bare attempt is refused
	h.anonymous().mustDo(http.MethodPost, "/api/v1/auth/register", jsonMap{
		"username": "stranger", "password": "long enough password",
	}, nil, http.StatusForbidden)

	// a bad code is refused too
	h.anonymous().mustDo(http.MethodPost, "/api/v1/auth/register", jsonMap{
		"username": "stranger", "password": "long enough password", "invite_code": "NOPE-NOPE",
	}, nil, http.StatusBadRequest)

	member := h.invite(admin, "mom", "another long password")
	if member.UserID == "" {
		t.Fatal("the invited account did not come back signed in")
	}

	// one invite, one account
	var invites struct {
		Invites []jsonMap `json:"invites"`
	}
	admin.mustDo(http.MethodGet, "/api/v1/admin/invites", nil, &invites, http.StatusOK)
	if len(invites.Invites) != 1 {
		t.Fatalf("expected one invite, got %d", len(invites.Invites))
	}
	if usable, _ := invites.Invites[0]["usable"].(bool); usable {
		t.Fatal("a redeemed invite must not still be usable")
	}
}

func TestFolderAndFileLifecycle(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	folderID := admin.createFolder("", "Documents")
	nested := admin.createFolder(folderID, "Receipts")

	content := []byte("a small text file for the test")
	fileID := admin.upload(folderID, "notes.txt", "text/plain", content)

	items := admin.listNodes(folderID)
	if len(items) != 2 {
		t.Fatalf("expected two items in the folder, got %d: %v", len(items), names(items))
	}
	// folders sort above files, the way every file manager does
	if kind, _ := items[0]["type"].(string); kind != "folder" {
		t.Fatalf("expected the folder first, got %v", names(items))
	}

	status, body, headers := admin.download(fileID, "")
	if status != http.StatusOK {
		t.Fatalf("download returned %d", status)
	}
	if !bytes.Equal(body, content) {
		t.Fatalf("downloaded bytes do not match what was uploaded")
	}
	if headers.Get("Accept-Ranges") != "bytes" {
		t.Fatal("downloads must advertise range support")
	}
	if !strings.Contains(headers.Get("Cache-Control"), "immutable") {
		t.Fatal("a content addressed download should be immutably cacheable")
	}

	// range requests are what make video scrubbing and resumed downloads work
	status, part, _ := admin.download(fileID, "bytes=2-6")
	if status != http.StatusPartialContent {
		t.Fatalf("a range request returned %d, want 206", status)
	}
	if string(part) != string(content[2:7]) {
		t.Fatalf("range returned %q, want %q", part, content[2:7])
	}

	// rename, then move to the top level
	var renamed jsonMap
	admin.mustDo(http.MethodPatch, "/api/v1/nodes/"+fileID,
		jsonMap{"name": "renamed.txt"}, &renamed, http.StatusOK)
	if renamed["name"] != "renamed.txt" {
		t.Fatalf("rename did not take: %v", renamed["name"])
	}

	admin.mustDo(http.MethodPatch, "/api/v1/nodes/"+fileID,
		jsonMap{"parent_id": "root"}, nil, http.StatusOK)
	if len(admin.listNodes(folderID)) != 1 {
		t.Fatal("the file should have left the folder")
	}

	// a folder cannot be moved inside itself
	admin.mustDo(http.MethodPatch, "/api/v1/nodes/"+folderID,
		jsonMap{"parent_id": nested}, nil, http.StatusBadRequest)

	// trash, then restore, then permanently delete
	admin.mustDo(http.MethodDelete, "/api/v1/nodes/"+fileID, nil, nil, http.StatusOK)
	if contains(names(admin.listNodes("")), "renamed.txt") {
		t.Fatal("a trashed file must not appear in a listing")
	}
	var trash struct {
		Nodes []jsonMap `json:"nodes"`
	}
	admin.mustDo(http.MethodGet, "/api/v1/trash", nil, &trash, http.StatusOK)
	if len(trash.Nodes) != 1 {
		t.Fatalf("expected one item in the trash, got %d", len(trash.Nodes))
	}

	admin.mustDo(http.MethodPost, "/api/v1/nodes/"+fileID+"/restore", nil, nil, http.StatusOK)
	if !contains(names(admin.listNodes("")), "renamed.txt") {
		t.Fatal("a restored file should be back in its listing")
	}

	admin.mustDo(http.MethodDelete, "/api/v1/nodes/"+fileID, nil, nil, http.StatusOK)
	admin.mustDo(http.MethodDelete, "/api/v1/nodes/"+fileID+"/permanent", nil, nil, http.StatusNoContent)
	admin.mustDo(http.MethodGet, "/api/v1/nodes/"+fileID, nil, nil, http.StatusNotFound)
}

func TestNameCollisionsGetASuffix(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	folder := admin.createFolder("", "Photos")
	admin.upload(folder, "shot.jpg", "image/jpeg", []byte("first"))
	admin.upload(folder, "shot.jpg", "image/jpeg", []byte("second"))
	admin.upload(folder, "shot.jpg", "image/jpeg", []byte("third"))

	got := names(admin.listNodes(folder))
	for _, want := range []string{"shot.jpg", "shot (2).jpg", "shot (3).jpg"} {
		if !contains(got, want) {
			t.Fatalf("expected %q among %v", want, got)
		}
	}
}

func TestPermissionMatrixIsEnforcedServerSide(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	member := h.invite(admin, "mom", "another long password")

	folder := admin.createFolder("", "Shared Folder")
	fileID := admin.upload(folder, "family.txt", "text/plain", []byte("hello"))

	// before any grant, the folder does not exist as far as the member is
	// concerned: 404, not 403, so its existence is not confirmed
	member.mustDo(http.MethodGet, "/api/v1/nodes/"+folder, nil, nil, http.StatusNotFound)

	// share as a viewer
	admin.mustDo(http.MethodPost, "/api/v1/nodes/"+folder+"/permissions",
		jsonMap{"user_id": member.UserID, "role": "viewer"}, nil, http.StatusCreated)

	// a viewer may browse and download, including a file nested inside
	member.mustDo(http.MethodGet, "/api/v1/nodes/"+folder, nil, nil, http.StatusOK)
	if status, body, _ := member.download(fileID, ""); status != http.StatusOK || string(body) != "hello" {
		t.Fatalf("a viewer should be able to download, got %d", status)
	}
	// a star is that person's own bookmark, and viewer access is enough
	member.mustDo(http.MethodPost, "/api/v1/nodes/"+fileID+"/star", nil, nil, http.StatusNoContent)

	// a viewer may not rename, move, trash, or reshare
	member.mustDo(http.MethodPatch, "/api/v1/nodes/"+fileID,
		jsonMap{"name": "hijacked.txt"}, nil, http.StatusForbidden)
	member.mustDo(http.MethodDelete, "/api/v1/nodes/"+fileID, nil, nil, http.StatusForbidden)
	member.mustDo(http.MethodPost, "/api/v1/nodes/"+fileID+"/share",
		jsonMap{"allow_download": true}, nil, http.StatusForbidden)
	member.mustDo(http.MethodPost, "/api/v1/nodes/"+folder+"/permissions",
		jsonMap{"user_id": admin.UserID, "role": "editor"}, nil, http.StatusForbidden)

	// promote to editor
	admin.mustDo(http.MethodPost, "/api/v1/nodes/"+folder+"/permissions",
		jsonMap{"user_id": member.UserID, "role": "editor"}, nil, http.StatusCreated)

	// an editor may rename and add content
	member.mustDo(http.MethodPatch, "/api/v1/nodes/"+fileID,
		jsonMap{"name": "edited.txt"}, nil, http.StatusOK)
	member.createFolder(folder, "Editor Folder")

	// an editor still may not delete, move, or reshare, which is stricter than
	// a typical drive editor role and is the point
	member.mustDo(http.MethodDelete, "/api/v1/nodes/"+fileID, nil, nil, http.StatusForbidden)
	member.mustDo(http.MethodPatch, "/api/v1/nodes/"+fileID,
		jsonMap{"parent_id": "root"}, nil, http.StatusForbidden)
	member.mustDo(http.MethodPost, "/api/v1/nodes/"+folder+"/share",
		jsonMap{"allow_download": true}, nil, http.StatusForbidden)

	// revoking access is immediate
	admin.mustDo(http.MethodDelete,
		"/api/v1/nodes/"+folder+"/permissions/"+member.UserID, nil, nil, http.StatusNoContent)
	member.mustDo(http.MethodGet, "/api/v1/nodes/"+folder, nil, nil, http.StatusNotFound)
}

func TestAdminCannotReadAnotherAccountsFiles(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	member := h.invite(admin, "mom", "another long password")

	private := member.createFolder("", "Private")
	fileID := member.upload(private, "diary.txt", "text/plain", []byte("nobody else"))

	// admin manages the server, not everyone's content
	admin.mustDo(http.MethodGet, "/api/v1/nodes/"+private, nil, nil, http.StatusNotFound)
	admin.mustDo(http.MethodGet, "/api/v1/nodes/"+fileID, nil, nil, http.StatusNotFound)
	if status, _, _ := admin.download(fileID, ""); status != http.StatusNotFound {
		t.Fatalf("an admin downloading a member's private file returned %d, want 404", status)
	}
	if contains(names(admin.listNodes("")), "Private") {
		t.Fatal("a member's private folder must not show in an admin listing")
	}
}

func TestTrashHidesAnItemFromEveryoneItWasSharedWith(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	member := h.invite(admin, "mom", "another long password")

	folder := admin.createFolder("", "Trip")
	admin.mustDo(http.MethodPost, "/api/v1/nodes/"+folder+"/permissions",
		jsonMap{"user_id": member.UserID, "role": "viewer"}, nil, http.StatusCreated)
	member.mustDo(http.MethodGet, "/api/v1/nodes/"+folder, nil, nil, http.StatusOK)

	admin.mustDo(http.MethodDelete, "/api/v1/nodes/"+folder, nil, nil, http.StatusOK)

	// once the owner has taken it away there is nothing for a permission row
	// to point at
	member.mustDo(http.MethodGet, "/api/v1/nodes/"+folder, nil, nil, http.StatusNotFound)
	var shared struct {
		Nodes []jsonMap `json:"nodes"`
	}
	member.mustDo(http.MethodGet, "/api/v1/nodes?filter=shared", nil, &shared, http.StatusOK)
	if len(shared.Nodes) != 0 {
		t.Fatalf("a trashed shared folder should be gone from the shared tab, got %v", names(shared.Nodes))
	}
}

func TestSharedItemsAppearInTheBlendedRootWithAnOwnerBadge(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	member := h.invite(admin, "mom", "another long password")

	member.createFolder("", "My Own Folder")
	shared := admin.createFolder("", "From Dad")
	admin.mustDo(http.MethodPost, "/api/v1/nodes/"+shared+"/permissions",
		jsonMap{"user_id": member.UserID, "role": "viewer"}, nil, http.StatusCreated)

	root := member.listNodes("")
	if len(root) != 2 {
		t.Fatalf("the blended root should hold both, got %v", names(root))
	}
	var badge jsonMap
	for _, item := range root {
		if item["name"] == "From Dad" {
			badge = item
		}
	}
	if badge == nil {
		t.Fatal("the shared folder is missing from the blended root")
	}
	owner, ok := badge["owner"].(map[string]any)
	if !ok || owner["name"] != "owner" {
		t.Fatalf("a shared item must carry its owner for the badge, got %v", badge["owner"])
	}
	if withMe, _ := badge["shared_with_me"].(bool); !withMe {
		t.Fatal("a shared item must be marked as shared with me")
	}
	if role, _ := badge["role"].(string); role != "viewer" {
		t.Fatalf("the resolved role should be viewer, got %q", role)
	}

	// the same item, on its own, is not marked shared for its owner
	ownersView := admin.listNodes("")
	for _, item := range ownersView {
		if item["name"] == "From Dad" {
			if withMe, _ := item["shared_with_me"].(bool); withMe {
				t.Fatal("an owner should not see their own folder as shared with them")
			}
		}
	}
}

func TestStarsArePerPerson(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	member := h.invite(admin, "mom", "another long password")

	folder := admin.createFolder("", "Recipes")
	admin.mustDo(http.MethodPost, "/api/v1/nodes/"+folder+"/permissions",
		jsonMap{"user_id": member.UserID, "role": "viewer"}, nil, http.StatusCreated)

	member.mustDo(http.MethodPost, "/api/v1/nodes/"+folder+"/star", nil, nil, http.StatusNoContent)

	var memberStars, ownerStars struct {
		Nodes []jsonMap `json:"nodes"`
	}
	member.mustDo(http.MethodGet, "/api/v1/nodes?filter=starred", nil, &memberStars, http.StatusOK)
	if len(memberStars.Nodes) != 1 {
		t.Fatalf("the person who starred it should see one starred item, got %d", len(memberStars.Nodes))
	}
	admin.mustDo(http.MethodGet, "/api/v1/nodes?filter=starred", nil, &ownerStars, http.StatusOK)
	if len(ownerStars.Nodes) != 0 {
		t.Fatal("one person's bookmark must stay invisible in the owner's own view")
	}
}

func TestPublicShareLinkLifecycle(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	fileID := admin.upload("", "public.txt", "text/plain", []byte("share me"))

	var share jsonMap
	admin.mustDo(http.MethodPost, "/api/v1/nodes/"+fileID+"/share",
		jsonMap{"allow_download": true}, &share, http.StatusCreated)
	token, _ := share["token"].(string)
	if token == "" {
		t.Fatal("the share came back with no token")
	}

	anon := h.anonymous()
	status, body := anon.getRaw("/s/" + token)
	if status != http.StatusOK {
		t.Fatalf("a public share returned %d: %s", status, body)
	}
	status, downloaded := anon.getRaw("/s/" + token + "/download")
	if status != http.StatusOK || string(downloaded) != "share me" {
		t.Fatalf("public download returned %d: %s", status, downloaded)
	}

	// turn download off in place, without changing the url
	admin.mustDo(http.MethodPatch, "/api/v1/shares/"+share["id"].(string),
		jsonMap{"allow_download": false}, nil, http.StatusOK)
	if status, _ := anon.getRaw("/s/" + token + "/download"); status != http.StatusForbidden {
		t.Fatalf("a view only link should refuse a download, got %d", status)
	}

	// a password takes effect immediately, on the same url
	admin.mustDo(http.MethodPatch, "/api/v1/shares/"+share["id"].(string),
		jsonMap{"password": "a long share password", "allow_download": true}, nil, http.StatusOK)
	if status, _ := anon.getRaw("/s/" + token); status != http.StatusUnauthorized {
		t.Fatalf("a password protected link should ask for one, got %d", status)
	}
	if status, _ := anon.getRaw("/s/" + token + "?password=" + url.QueryEscape("a long share password")); status != http.StatusOK {
		t.Fatal("the correct password should open the link")
	}
	if status, _ := anon.getRaw("/s/" + token + "?password=wrong"); status != http.StatusUnauthorized {
		t.Fatal("a wrong password must be refused")
	}

	// revoking is immediate
	admin.mustDo(http.MethodDelete, "/api/v1/shares/"+share["id"].(string), nil, nil, http.StatusNoContent)
	if status, _ := anon.getRaw("/s/" + token + "?password=" + url.QueryEscape("a long share password")); status != http.StatusNotFound {
		t.Fatalf("a revoked link should be gone, got %d", status)
	}
}

func TestShareExpiryIsCheckedOnEveryAccess(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	fileID := admin.upload("", "temporary.txt", "text/plain", []byte("not for long"))

	// an expiry in the past is refused outright
	admin.mustDo(http.MethodPost, "/api/v1/nodes/"+fileID+"/share",
		jsonMap{"expires_at": time.Now().Add(-time.Hour).UnixMilli()}, nil, http.StatusBadRequest)

	var share jsonMap
	expiry := time.Now().Add(900 * time.Millisecond).UnixMilli()
	admin.mustDo(http.MethodPost, "/api/v1/nodes/"+fileID+"/share",
		jsonMap{"expires_at": expiry, "allow_download": true}, &share, http.StatusCreated)
	token := share["token"].(string)

	anon := h.anonymous()
	if status, _ := anon.getRaw("/s/" + token); status != http.StatusOK {
		t.Fatal("the link should work before it expires")
	}

	time.Sleep(1200 * time.Millisecond)

	// the live comparison, not the sweep job, is what enforces this, so there
	// is no window where an expired link still works
	if status, _ := anon.getRaw("/s/" + token); status != http.StatusGone {
		t.Fatalf("an expired link should return 410, got %d", status)
	}
	if status, _ := anon.getRaw("/s/" + token + "/download"); status != http.StatusGone {
		t.Fatal("an expired link must not serve bytes either")
	}
}

func TestVersionHistory(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	fileID := admin.upload("", "draft.txt", "text/plain", []byte("first draft"))
	admin.uploadReplacing("", fileID, "draft.txt", "text/plain", []byte("second draft"))

	var versions struct {
		Versions []jsonMap `json:"versions"`
	}
	admin.mustDo(http.MethodGet, "/api/v1/nodes/"+fileID+"/versions", nil, &versions, http.StatusOK)
	if len(versions.Versions) != 1 {
		t.Fatalf("expected one prior version, got %d", len(versions.Versions))
	}

	if _, body, _ := admin.download(fileID, ""); string(body) != "second draft" {
		t.Fatalf("the current bytes should be the newest, got %q", body)
	}

	versionID := versions.Versions[0]["id"].(string)
	admin.mustDo(http.MethodPost,
		fmt.Sprintf("/api/v1/nodes/%s/versions/%s/restore", fileID, versionID),
		nil, nil, http.StatusOK)

	if _, body, _ := admin.download(fileID, ""); string(body) != "first draft" {
		t.Fatalf("restoring a version should bring back its bytes, got %q", body)
	}
	// restoring keeps the outgoing bytes, so the move is itself reversible
	admin.mustDo(http.MethodGet, "/api/v1/nodes/"+fileID+"/versions", nil, &versions, http.StatusOK)
	if len(versions.Versions) != 1 {
		t.Fatalf("expected the replaced bytes to be kept as a version, got %d", len(versions.Versions))
	}
}

func TestResumableUploadPicksUpWhereItStopped(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	content := bytes.Repeat([]byte("resumable payload "), 500)
	nodeID := admin.uploadInChunks("", "big.bin", content, len(content)/3)

	status, body, _ := admin.download(nodeID, "")
	if status != http.StatusOK {
		t.Fatalf("download after a resumed upload returned %d", status)
	}
	if !bytes.Equal(body, content) {
		t.Fatal("the resumed upload did not reassemble byte for byte")
	}
}

func TestDeduplicationSharesOneObject(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	content := []byte("exactly the same bytes twice")
	first := admin.upload("", "one.txt", "text/plain", content)
	second := admin.upload("", "two.txt", "text/plain", content)

	var a, b jsonMap
	admin.mustDo(http.MethodGet, "/api/v1/nodes/"+first, nil, &a, http.StatusOK)
	admin.mustDo(http.MethodGet, "/api/v1/nodes/"+second, nil, &b, http.StatusOK)
	if a["checksum_sha256"] != b["checksum_sha256"] {
		t.Fatal("identical content must land on one checksum")
	}

	// deleting one must not take the other's bytes with it
	admin.mustDo(http.MethodDelete, "/api/v1/nodes/"+first, nil, nil, http.StatusOK)
	admin.mustDo(http.MethodDelete, "/api/v1/nodes/"+first+"/permanent", nil, nil, http.StatusNoContent)

	status, body, _ := admin.download(second, "")
	if status != http.StatusOK || !bytes.Equal(body, content) {
		t.Fatalf("the surviving copy should still read, got %d", status)
	}
}

func TestQuotaIsEnforced(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")
	member := h.invite(admin, "mom", "another long password")

	admin.mustDo(http.MethodPatch, "/api/v1/admin/users/"+member.UserID+"/quota",
		jsonMap{"quota_bytes": 64}, nil, http.StatusNoContent)

	// under quota is fine
	member.upload("", "small.txt", "text/plain", []byte("tiny"))

	// over quota is refused at creation time, before a byte is accepted
	oversized := bytes.Repeat([]byte("x"), 1024)
	req := newUploadCreate(t, h, member, "", "big.txt", oversized)
	resp, err := h.server.Client().Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusInsufficientStorage {
		t.Fatalf("an over quota upload returned %d, want 507", resp.StatusCode)
	}
}

func TestIdempotencyKeyReplaysTheFirstResult(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	body, _ := json.Marshal(jsonMap{"name": "Only Once"})
	send := func() jsonMap {
		req, _ := http.NewRequest(http.MethodPost,
			h.server.URL+"/api/v1/nodes/folder", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+admin.AccessToken)
		req.Header.Set("Idempotency-Key", "retry-after-a-network-blip")
		resp, err := h.server.Client().Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		var out jsonMap
		_ = json.NewDecoder(resp.Body).Decode(&out)
		return out
	}

	first := send()
	second := send()
	if first["id"] != second["id"] {
		t.Fatalf("a retried create made a second folder: %v then %v", first["id"], second["id"])
	}
	if count := len(admin.listNodes("")); count != 1 {
		t.Fatalf("expected exactly one folder, got %d", count)
	}
}

func TestPathTraversalIsRefusedAtTheApiLayer(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	for _, name := range []string{"../escape", "..", "a/b", `a\b`, "", "   "} {
		admin.mustDo(http.MethodPost, "/api/v1/nodes/folder",
			jsonMap{"name": name}, nil, http.StatusBadRequest)
	}
}

func TestSessionRevocationEndsAccessImmediately(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	admin.mustDo(http.MethodGet, "/api/v1/me", nil, nil, http.StatusOK)
	admin.mustDo(http.MethodPost, "/api/v1/auth/logout", nil, nil, http.StatusNoContent)
	admin.mustDo(http.MethodGet, "/api/v1/me", nil, nil, http.StatusUnauthorized)

	// a revoked refresh token cannot mint a new session either
	anon := h.anonymous()
	anon.mustDo(http.MethodPost, "/api/v1/auth/refresh",
		jsonMap{"refresh_token": admin.RefreshToken}, nil, http.StatusUnauthorized)
}

func TestRefreshTokensRotateAndAreSingleUse(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	original := admin.RefreshToken
	var out jsonMap
	h.anonymous().mustDo(http.MethodPost, "/api/v1/auth/refresh",
		jsonMap{"refresh_token": original}, &out, http.StatusOK)
	rotated, _ := out["refresh_token"].(string)
	if rotated == "" || rotated == original {
		t.Fatal("a refresh must hand back a different token")
	}

	// replaying the old one finds nothing to rotate
	h.anonymous().mustDo(http.MethodPost, "/api/v1/auth/refresh",
		jsonMap{"refresh_token": original}, nil, http.StatusUnauthorized)
}

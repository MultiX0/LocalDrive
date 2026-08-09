package httpapi

import (
	"testing"

	"github.com/MultiX0/LocalDrive/server/internal/models"
)

// An admin can change quotas, reset passwords and remove accounts, so that
// account is not left on a password alone. Members decide for themselves.
//
// The client turns this flag into a gate it cannot navigate past, so getting
// it wrong either locks a member out of an optional feature or quietly leaves
// an admin unprotected.
func TestMustEnableTOTP(t *testing.T) {
	cases := []struct {
		name    string
		role    models.Role
		enabled bool
		want    bool
	}{
		{"admin without two factor is required to set it up", models.RoleAdmin, false, true},
		{"admin who already has it is left alone", models.RoleAdmin, true, false},
		{"member without it is not forced", models.RoleMember, false, false},
		{"member who chose it keeps it", models.RoleMember, true, false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			body := userBody(models.User{
				ID:          "u1",
				Username:    "someone",
				Role:        tc.role,
				TOTPEnabled: tc.enabled,
			})
			if body.MustEnableTOTP != tc.want {
				t.Fatalf("MustEnableTOTP = %v, want %v", body.MustEnableTOTP, tc.want)
			}
			// the raw flag has to survive alongside it: the settings screen
			// shows "on" from this, not from the gate
			if body.TOTPEnabled != tc.enabled {
				t.Fatalf("TOTPEnabled = %v, want %v", body.TOTPEnabled, tc.enabled)
			}
		})
	}
}

// The response is read by every client on every request, so the shape of it is
// worth pinning: a missing field reads as false, which would silently drop the
// requirement rather than fail loudly.
func TestUserBodyCarriesBothTOTPFields(t *testing.T) {
	body := userBody(models.User{Role: models.RoleAdmin})
	if !body.MustEnableTOTP {
		t.Fatal("a fresh admin should be asked to enrol")
	}
	if body.TOTPEnabled {
		t.Fatal("a fresh admin has not enrolled yet")
	}
}

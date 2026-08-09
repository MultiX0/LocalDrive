package files

import (
	"testing"

	"github.com/MultiX0/LocalDrive/server/internal/models"
)

// TestCapabilityMatrix pins the exact table from the plan. Deletion and
// sharing are owner only on purpose, even above what a typical editor role
// would allow, so a shared item cannot be deleted or reshared out from under
// its owner.
func TestCapabilityMatrix(t *testing.T) {
	type row struct {
		name   string
		cap    Capability
		viewer bool
		editor bool
		owner  bool
	}
	rows := []row{
		{"browse, preview, download", CapBrowse, true, true, true},
		{"star, own bookmark only", CapStar, true, true, true},
		{"create inside", CapCreate, false, true, true},
		{"rename", CapRename, false, true, true},
		{"upload a new version", CapUploadVersion, false, true, true},
		{"move", CapMove, false, false, true},
		{"recolor folders", CapRecolor, false, false, true},
		{"trash, restore, permanently delete", CapTrash, false, false, true},
		{"change sharing and permissions", CapShare, false, false, true},
	}
	for _, r := range rows {
		t.Run(r.name, func(t *testing.T) {
			if got := Can(models.AccessNone, r.cap); got {
				t.Fatalf("no access should never allow %s", r.name)
			}
			if got := Can(models.AccessViewer, r.cap); got != r.viewer {
				t.Fatalf("viewer %s = %v, want %v", r.name, got, r.viewer)
			}
			if got := Can(models.AccessEditor, r.cap); got != r.editor {
				t.Fatalf("editor %s = %v, want %v", r.name, got, r.editor)
			}
			if got := Can(models.AccessOwner, r.cap); got != r.owner {
				t.Fatalf("owner %s = %v, want %v", r.name, got, r.owner)
			}
		})
	}
}

func TestUnknownCapabilityIsRefused(t *testing.T) {
	if Can(models.AccessOwner, Capability(999)) {
		t.Fatal("an unrecognized capability must default to refused, even for an owner")
	}
}

func TestAccessRequire(t *testing.T) {
	viewer := Access{Role: models.AccessViewer}
	if err := viewer.Require(CapBrowse); err != nil {
		t.Fatalf("a viewer should be able to browse, got %v", err)
	}
	if err := viewer.Require(CapTrash); err == nil {
		t.Fatal("a viewer must not be able to trash anything")
	}
}

func TestAccessRoleString(t *testing.T) {
	cases := map[models.AccessRole]string{
		models.AccessNone:   "none",
		models.AccessViewer: "viewer",
		models.AccessEditor: "editor",
		models.AccessOwner:  "owner",
	}
	for role, want := range cases {
		if got := role.String(); got != want {
			t.Fatalf("%d.String() = %q, want %q", role, got, want)
		}
	}
}

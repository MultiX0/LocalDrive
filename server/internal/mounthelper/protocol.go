// Package mounthelper defines the tiny protocol between the main server and
// the privileged mount-helper process, and the client half of it. The helper
// listens on a Unix socket only, never a network port, and every call carries
// a shared secret generated at deploy time.
package mounthelper

// HeaderSecret authenticates every call to the helper.
const HeaderSecret = "X-Local-Drive-Secret"

// The five operations the helper recognizes, and nothing else.
const (
	PathList    = "/v1/list"
	PathMount   = "/v1/mount"
	PathUnmount = "/v1/unmount"
	PathFormat  = "/v1/format"
	PathPool    = "/v1/pool"
	PathHealth  = "/v1/health"
)

// FormatConfirmation is the exact phrase a format request must carry. The
// server requires the admin to type it, and the helper checks it again.
const FormatConfirmation = "ERASE THIS DRIVE"

// Drive is one detected block device.
type Drive struct {
	ID         string `json:"id"`
	Path       string `json:"path"`
	Name       string `json:"name"`
	Label      string `json:"label"`
	Filesystem string `json:"filesystem"`
	SizeBytes  int64  `json:"size_bytes"`
	Removable  bool   `json:"removable"`
	MountPoint string `json:"mount_point"`
	Model      string `json:"model"`
	Serial     string `json:"serial"`
	ReadOnly   bool   `json:"read_only"`
}

// Mounted reports whether the drive is already usable.
func (d Drive) Mounted() bool { return d.MountPoint != "" }

// Usable reports whether the drive carries a filesystem Local Drive can use
// without formatting it first.
func (d Drive) Usable() bool {
	switch d.Filesystem {
	case "ext4", "ext3", "ext2", "xfs", "btrfs", "exfat", "vfat", "ntfs", "f2fs":
		return true
	default:
		return false
	}
}

// ListResponse is the reply to PathList.
type ListResponse struct {
	Drives []Drive `json:"drives"`
}

// MountRequest asks the helper to mount one device.
type MountRequest struct {
	DeviceID string `json:"device_id"`
	Label    string `json:"label"`
	ReadOnly bool   `json:"read_only"`
}

// MountResponse reports where a device ended up.
type MountResponse struct {
	MountPoint string `json:"mount_point"`
	Filesystem string `json:"filesystem"`
}

// UnmountRequest asks the helper to release a mount point.
type UnmountRequest struct {
	MountPoint string `json:"mount_point"`
}

// FormatRequest erases a device. Guarded by the confirmation phrase.
type FormatRequest struct {
	DeviceID     string `json:"device_id"`
	Filesystem   string `json:"filesystem"`
	Label        string `json:"label"`
	Confirmation string `json:"confirmation"`
}

// PoolRequest combines already-mounted drives into one union mount.
type PoolRequest struct {
	Name        string   `json:"name"`
	MountPoints []string `json:"mount_points"`
}

// PoolResponse reports where the pool was mounted.
type PoolResponse struct {
	MountPoint string `json:"mount_point"`
}

// ErrorResponse is what the helper returns on any failure.
type ErrorResponse struct {
	Error string `json:"error"`
}

// HealthResponse reports the helper's own readiness.
type HealthResponse struct {
	OK       bool   `json:"ok"`
	Version  string `json:"version"`
	MergerFS bool   `json:"mergerfs"`
	RootPath string `json:"root_path"`
}

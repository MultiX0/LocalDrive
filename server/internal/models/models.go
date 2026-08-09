// Package models holds the row shapes shared by every internal package, so a
// node or a user is defined once and not re-declared per feature.
package models

// Role names a user's server-wide role.
type Role string

// Server-wide roles.
const (
	RoleAdmin  Role = "admin"
	RoleMember Role = "member"
)

// NodeType distinguishes the two kinds of row in nodes.
type NodeType string

// Node types.
const (
	NodeFile   NodeType = "file"
	NodeFolder NodeType = "folder"
)

// SessionStatus is the device-approval state machine.
type SessionStatus string

// Session states.
const (
	SessionPending SessionStatus = "pending"
	SessionActive  SessionStatus = "active"
	SessionRevoked SessionStatus = "revoked"
	SessionDenied  SessionStatus = "denied"
)

// LibraryKind names how a library's storage is backed.
type LibraryKind string

// Library kinds.
const (
	LibraryInternal LibraryKind = "internal"
	LibraryExternal LibraryKind = "external"
	LibraryNetwork  LibraryKind = "network"
	LibraryPooled   LibraryKind = "pooled"
)

// Library statuses.
const (
	LibraryOnline  = "online"
	LibraryOffline = "offline"
)

// AccessRole is a caller's resolved role against one node.
type AccessRole int

// Access roles, ordered so a numeric comparison means "at least".
const (
	AccessNone AccessRole = iota
	AccessViewer
	AccessEditor
	AccessOwner
)

// String renders an AccessRole for API responses.
func (r AccessRole) String() string {
	switch r {
	case AccessOwner:
		return "owner"
	case AccessEditor:
		return "editor"
	case AccessViewer:
		return "viewer"
	default:
		return "none"
	}
}

// User is one account.
type User struct {
	ID                 string
	Email              string
	Username           string
	DisplayName        string
	PasswordHash       string
	MustChangePassword bool
	Role               Role
	QuotaBytes         int64
	QuotaBytesUsed     int64
	AvatarSeed         string
	TOTPSecret         string
	TOTPEnabled        bool
	DisabledAt         int64
	CreatedAt          int64
	UpdatedAt          int64
}

// IsAdmin reports whether this account manages the server.
func (u *User) IsAdmin() bool { return u.Role == RoleAdmin }

// PublicName is what other accounts see in the People picker.
func (u *User) PublicName() string {
	if u.DisplayName != "" {
		return u.DisplayName
	}
	return u.Username
}

// Session is one device's login.
type Session struct {
	ID               string
	UserID           string
	DeviceName       string
	Platform         string
	Status           SessionStatus
	RefreshTokenHash string
	IP               string
	UserAgent        string
	CreatedAt        int64
	LastSeenAt       int64
	ExpiresAt        int64
	ApprovedAt       int64
	ApprovedBy       string
	RevokedAt        int64
}

// Node is a file or a folder.
type Node struct {
	ID                   string
	ParentID             string
	OwnerID              string
	LibraryID            string
	Name                 string
	Type                 NodeType
	MimeType             string
	SizeBytes            int64
	ChecksumSHA256       string
	Color                string
	HasThumbnail         bool
	ThumbnailGeneratedAt int64

	// pixel dimensions, so a client can lay out a photo grid before a single
	// thumbnail has arrived. Zero for anything that is not an image
	ImageWidth  int
	ImageHeight int

	// when the picture was taken, out of the file's own metadata. Genuinely
	// different from CreatedAt, which is when it was uploaded here. Zero when
	// the file carries no capture time
	TakenAt      int64
	VersionCount int
	CreatedAt    int64
	UpdatedAt    int64
	TrashedAt    int64
	DeletedAt    int64
}

// IsFolder is the check written most often in the files package.
func (n *Node) IsFolder() bool { return n.Type == NodeFolder }

// NodeVersion is one prior state of a file.
type NodeVersion struct {
	ID             string
	NodeID         string
	SizeBytes      int64
	ChecksumSHA256 string
	MimeType       string
	CreatedBy      string
	CreatedAt      int64
}

// Permission is one explicit grant of access on one node.
type Permission struct {
	ID        string
	NodeID    string
	UserID    string
	Role      string
	CreatedBy string
	CreatedAt int64
}

// Share is a public link to a node.
type Share struct {
	ID            string
	NodeID        string
	Token         string
	PasswordHash  string
	ExpiresAt     int64
	AllowDownload bool
	CreatedBy     string
	CreatedAt     int64
	RevokedAt     int64
}

// Active reports whether a share may still be served right now. The live
// check, not the sweep job, is what actually enforces expiry.
func (s *Share) Active(nowMillis int64) bool {
	if s.RevokedAt != 0 {
		return false
	}
	if s.ExpiresAt != 0 && s.ExpiresAt <= nowMillis {
		return false
	}
	return true
}

// Library is one storage root.
type Library struct {
	ID         string
	Name       string
	RootPath   string
	Kind       LibraryKind
	IsExternal bool
	IsDefault  bool
	Status     string
	DeviceID   string
	Members    []string
	BytesUsed  int64
	CreatedAt  int64
	UpdatedAt  int64
	TotalBytes int64 // read live from the OS, never stored
	FreeBytes  int64
	StatsKnown bool
}

// Online reports whether the backing device is currently present.
func (l *Library) Online() bool { return l.Status == LibraryOnline }

// Invite is one account-creation code.
type Invite struct {
	ID        string
	Code      string
	Label     string
	CreatedBy string
	ExpiresAt int64
	UsedBy    string
	UsedAt    int64
	RevokedAt int64
	CreatedAt int64
}

// Usable reports whether an invite can still be redeemed.
func (i *Invite) Usable(nowMillis int64) bool {
	if i.RevokedAt != 0 || i.UsedAt != 0 {
		return false
	}
	if i.ExpiresAt != 0 && i.ExpiresAt <= nowMillis {
		return false
	}
	return true
}

// ServerSettings is the single runtime-editable settings row.
type ServerSettings struct {
	ServerID              string
	ServerName            string
	RequireDeviceApproval bool
	EnableLANDiscovery    bool
	AllowSelfRegistration bool
	TrashRetentionDays    int
	VersionRetentionCount int
	VersionRetentionDays  int
	SetupCompletedAt      int64
	CreatedAt             int64
	UpdatedAt             int64
}

// Activity is one audit-log row.
type Activity struct {
	ID        string
	UserID    string
	NodeID    string
	Action    string
	Metadata  map[string]any
	IP        string
	CreatedAt int64
}

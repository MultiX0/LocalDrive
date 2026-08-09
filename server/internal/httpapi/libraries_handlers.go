package httpapi

import (
	"errors"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/libraries"
	mw "github.com/MultiX0/LocalDrive/server/internal/middleware"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/mounthelper"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
	"github.com/MultiX0/LocalDrive/server/pkg/pathsafe"
)

type libraryDTO struct {
	ID         string   `json:"id"`
	Name       string   `json:"name"`
	Kind       string   `json:"kind"`
	IsExternal bool     `json:"is_external"`
	IsDefault  bool     `json:"is_default"`
	Status     string   `json:"status"`
	BytesUsed  int64    `json:"bytes_used"`
	TotalBytes int64    `json:"total_bytes,omitempty"`
	FreeBytes  int64    `json:"free_bytes,omitempty"`
	StatsKnown bool     `json:"stats_known"`
	Members    []string `json:"members,omitempty"`
	CreatedAt  int64    `json:"created_at"`
}

func libraryBody(l models.Library) libraryDTO {
	return libraryDTO{
		ID: l.ID, Name: l.Name, Kind: string(l.Kind), IsExternal: l.IsExternal,
		IsDefault: l.IsDefault, Status: l.Status, BytesUsed: l.BytesUsed,
		TotalBytes: l.TotalBytes, FreeBytes: l.FreeBytes, StatsKnown: l.StatsKnown,
		Members: l.Members, CreatedAt: l.CreatedAt,
	}
}

func (a *API) handleListLibraries(w http.ResponseWriter, r *http.Request) {
	list, err := a.libs.List(r.Context())
	if err != nil {
		a.fail(w, r, err)
		return
	}
	out := make([]libraryDTO, 0, len(list))
	var totalUsed, totalFree, totalSize int64
	for _, l := range list {
		out = append(out, libraryBody(l))
		totalUsed += l.BytesUsed
		if l.StatsKnown {
			totalFree += l.FreeBytes
			totalSize += l.TotalBytes
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"libraries":   out,
		"total_used":  totalUsed,
		"total_free":  totalFree,
		"total_bytes": totalSize,
	})
}

type registerLibraryRequest struct {
	Name        string `json:"name"`
	Path        string `json:"path"`
	Kind        string `json:"kind"`
	MakeDefault bool   `json:"make_default"`
}

// handleRegisterLibrary turns a detected mount into a library. The path must
// already sit under the external mounts directory; nothing else is accepted.
func (a *API) handleRegisterLibrary(w http.ResponseWriter, r *http.Request) {
	user, _ := mw.UserFrom(r.Context())
	if !user.IsAdmin() {
		writeError(w, http.StatusForbidden, "forbidden", "that is an admin action")
		return
	}
	var req registerLibraryRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	clean := filepath.Clean(strings.TrimSpace(req.Path))
	if !pathsafe.Within(a.cfg.ExternalMountsPath, clean) {
		writeError(w, http.StatusBadRequest, "invalid_request",
			fmt.Sprintf("a library must live under %s", a.cfg.ExternalMountsPath))
		return
	}
	kind := models.LibraryKind(strings.TrimSpace(req.Kind))
	if kind == "" {
		kind = models.LibraryExternal
	}
	lib, err := a.libs.Register(r.Context(), libraries.RegisterOptions{
		Name: req.Name, RootPath: clean, Kind: kind,
		IsExternal: kind != models.LibraryInternal, MakeDefault: req.MakeDefault,
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	a.audit.Record(r.Context(), audit.Entry{
		UserID: user.ID, Action: audit.ActionLibraryRegistered, IP: clientIP(r),
		Metadata: map[string]any{"library": lib.ID, "path": clean, "kind": string(kind)},
	})
	a.broadcastLibraries(r)
	writeJSON(w, http.StatusCreated, libraryBody(lib))
}

type renameLibraryRequest struct {
	Name string `json:"name"`
}

func (a *API) handleRenameLibrary(w http.ResponseWriter, r *http.Request) {
	user, _ := mw.UserFrom(r.Context())
	if !user.IsAdmin() {
		writeError(w, http.StatusForbidden, "forbidden", "that is an admin action")
		return
	}
	var req renameLibraryRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if err := a.libs.Rename(r.Context(), chi.URLParam(r, "id"), req.Name); err != nil {
		a.fail(w, r, err)
		return
	}
	lib, err := a.libs.Get(chi.URLParam(r, "id"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	a.broadcastLibraries(r)
	writeJSON(w, http.StatusOK, libraryBody(lib))
}

func (a *API) handleSetDefaultLibrary(w http.ResponseWriter, r *http.Request) {
	user, _ := mw.UserFrom(r.Context())
	if !user.IsAdmin() {
		writeError(w, http.StatusForbidden, "forbidden", "that is an admin action")
		return
	}
	id := chi.URLParam(r, "id")
	if err := a.libs.SetDefault(r.Context(), id); err != nil {
		a.fail(w, r, err)
		return
	}
	a.audit.Record(r.Context(), audit.Entry{
		UserID: user.ID, Action: audit.ActionLibraryDefaultSet, IP: clientIP(r),
		Metadata: map[string]any{"library": id},
	})
	a.broadcastLibraries(r)
	w.WriteHeader(http.StatusNoContent)
}

// handleEjectLibrary flushes and unmounts a drive before telling the admin it
// is safe to unplug, rather than leaving that to chance.
func (a *API) handleEjectLibrary(w http.ResponseWriter, r *http.Request) {
	user, _ := mw.UserFrom(r.Context())
	if !user.IsAdmin() {
		writeError(w, http.StatusForbidden, "forbidden", "that is an admin action")
		return
	}
	id := chi.URLParam(r, "id")
	lib, err := a.libs.Get(id)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	if !lib.IsExternal {
		writeError(w, http.StatusBadRequest, "invalid_request", "this library is not a removable drive")
		return
	}
	if !a.mounts.Enabled() {
		writeError(w, http.StatusServiceUnavailable, "helper_unavailable",
			"drive management is not available on this deployment, unmount it on the host instead")
		return
	}
	// the audit entry is written before the helper is asked to act
	a.audit.Record(r.Context(), audit.Entry{
		UserID: user.ID, Action: audit.ActionDriveEjected, IP: clientIP(r),
		Metadata: map[string]any{"library": id, "path": lib.RootPath},
	})
	if err := a.mounts.Unmount(r.Context(), lib.RootPath); err != nil {
		a.fail(w, r, err)
		return
	}
	if err := a.libs.SetStatus(r.Context(), id, models.LibraryOffline); err != nil {
		a.fail(w, r, err)
		return
	}
	a.broadcastLibraries(r)
	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "ejected",
		"message": "it is safe to unplug this drive now",
	})
}

// detected drives, admin only

type driveDTO struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Label      string `json:"label"`
	Filesystem string `json:"filesystem"`
	SizeBytes  int64  `json:"size_bytes"`
	Removable  bool   `json:"removable"`
	MountPoint string `json:"mount_point,omitempty"`
	Model      string `json:"model,omitempty"`
	Mounted    bool   `json:"mounted"`
	Usable     bool   `json:"usable"`
	InUse      bool   `json:"in_use"`
	ReadOnly   bool   `json:"read_only"`
}

func (a *API) handleListDrives(w http.ResponseWriter, r *http.Request) {
	if !a.mounts.Enabled() {
		writeJSON(w, http.StatusOK, map[string]any{
			"drives":           []driveDTO{},
			"helper_available": false,
			"message":          "drive management is not available on this deployment",
		})
		return
	}
	drives, err := a.mounts.List(r.Context())
	if err != nil {
		if errors.Is(err, mounthelper.ErrUnavailable) {
			writeJSON(w, http.StatusOK, map[string]any{
				"drives":           []driveDTO{},
				"helper_available": false,
				"message":          "the drive helper is not answering",
			})
			return
		}
		a.fail(w, r, err)
		return
	}
	registered := map[string]struct{}{}
	if list, err := a.libs.List(r.Context()); err == nil {
		for _, lib := range list {
			registered[filepath.Clean(lib.RootPath)] = struct{}{}
		}
	}
	out := make([]driveDTO, 0, len(drives))
	for _, d := range drives {
		_, inUse := registered[filepath.Clean(d.MountPoint)]
		out = append(out, driveDTO{
			ID: d.ID, Name: d.Name, Label: d.Label, Filesystem: d.Filesystem,
			SizeBytes: d.SizeBytes, Removable: d.Removable, MountPoint: d.MountPoint,
			Model: d.Model, Mounted: d.Mounted(), Usable: d.Usable(), InUse: inUse,
			ReadOnly: d.ReadOnly,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"drives": out, "helper_available": true})
}

type mountDriveRequest struct {
	Label       string `json:"label"`
	MakeDefault bool   `json:"make_default"`
}

// handleMountDrive is the one-tap Use this drive action: mount it, register it
// as a library, done, no terminal.
func (a *API) handleMountDrive(w http.ResponseWriter, r *http.Request) {
	var req mountDriveRequest
	if !decodeQuiet(r, &req) {
		req = mountDriveRequest{}
	}
	user, _ := mw.UserFrom(r.Context())
	deviceID := chi.URLParam(r, "id")
	if !a.mounts.Enabled() {
		writeError(w, http.StatusServiceUnavailable, "helper_unavailable",
			"drive management is not available on this deployment")
		return
	}
	a.audit.Record(r.Context(), audit.Entry{
		UserID: user.ID, Action: audit.ActionDriveMounted, IP: clientIP(r),
		Metadata: map[string]any{"device": deviceID},
	})
	resp, err := a.mounts.Mount(r.Context(), mounthelper.MountRequest{
		DeviceID: deviceID, Label: req.Label,
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	name := strings.TrimSpace(req.Label)
	if name == "" {
		name = filepath.Base(resp.MountPoint)
	}
	lib, err := a.libs.Register(r.Context(), libraries.RegisterOptions{
		Name: name, RootPath: resp.MountPoint, Kind: models.LibraryExternal,
		IsExternal: true, MakeDefault: req.MakeDefault,
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	a.broadcastLibraries(r)
	writeJSON(w, http.StatusCreated, libraryBody(lib))
}

type formatDriveRequest struct {
	Filesystem   string `json:"filesystem"`
	Label        string `json:"label"`
	Confirmation string `json:"confirmation"`
}

// handleFormatDrive is the one destructive action in the storage flow, so it
// takes an exact confirmation phrase and is checked again by the helper.
func (a *API) handleFormatDrive(w http.ResponseWriter, r *http.Request) {
	var req formatDriveRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Confirmation != mounthelper.FormatConfirmation {
		writeError(w, http.StatusBadRequest, "confirmation_required",
			"type the confirmation phrase exactly to erase this drive")
		return
	}
	if !a.mounts.Enabled() {
		writeError(w, http.StatusServiceUnavailable, "helper_unavailable",
			"drive management is not available on this deployment")
		return
	}
	user, _ := mw.UserFrom(r.Context())
	deviceID := chi.URLParam(r, "id")
	fs := strings.TrimSpace(req.Filesystem)
	if fs == "" {
		fs = "ext4"
	}
	a.audit.Record(r.Context(), audit.Entry{
		UserID: user.ID, Action: audit.ActionDriveFormatted, IP: clientIP(r),
		Metadata: map[string]any{"device": deviceID, "filesystem": fs},
	})
	err := a.mounts.Format(r.Context(), mounthelper.FormatRequest{
		DeviceID: deviceID, Filesystem: fs, Label: req.Label, Confirmation: req.Confirmation,
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "formatted"})
}

type poolRequest struct {
	Name        string   `json:"name"`
	LibraryIDs  []string `json:"library_ids"`
	MakeDefault bool     `json:"make_default"`
}

// handlePoolDrives combines mounted drives into one union mount. Capacity
// only, never redundancy, which the client states plainly before confirming.
func (a *API) handlePoolDrives(w http.ResponseWriter, r *http.Request) {
	var req poolRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.LibraryIDs) < 2 {
		writeError(w, http.StatusBadRequest, "invalid_request", "pick at least two drives")
		return
	}
	if !a.mounts.Enabled() {
		writeError(w, http.StatusServiceUnavailable, "helper_unavailable",
			"drive management is not available on this deployment")
		return
	}
	user, _ := mw.UserFrom(r.Context())
	var mountPoints []string
	for _, id := range req.LibraryIDs {
		lib, err := a.libs.Get(id)
		if err != nil {
			a.fail(w, r, err)
			return
		}
		if !lib.IsExternal || !lib.Online() {
			writeError(w, http.StatusBadRequest, "invalid_request",
				"every drive in a pool must be an external drive that is connected")
			return
		}
		mountPoints = append(mountPoints, lib.RootPath)
	}
	name := strings.TrimSpace(req.Name)
	if err := pathsafe.ValidateName(name); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "give the combined drive a simple name")
		return
	}
	a.audit.Record(r.Context(), audit.Entry{
		UserID: user.ID, Action: audit.ActionDrivePooled, IP: clientIP(r),
		Metadata: map[string]any{"name": name, "members": mountPoints},
	})
	resp, err := a.mounts.Pool(r.Context(), mounthelper.PoolRequest{Name: name, MountPoints: mountPoints})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	lib, err := a.libs.Register(r.Context(), libraries.RegisterOptions{
		Name: name, RootPath: resp.MountPoint, Kind: models.LibraryPooled,
		IsExternal: true, MakeDefault: req.MakeDefault, Members: req.LibraryIDs,
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	a.broadcastLibraries(r)
	writeJSON(w, http.StatusCreated, libraryBody(lib))
}

func (a *API) broadcastLibraries(r *http.Request) {
	users, err := a.auth.ListPublicUsers(r.Context(), "")
	if err != nil {
		return
	}
	ids := make([]string, 0, len(users))
	for _, u := range users {
		ids = append(ids, u.ID)
	}
	a.hub.Publish(ws.NewEvent(ws.EventLibraryChanged, nowMillis(), nil), ids...)
}

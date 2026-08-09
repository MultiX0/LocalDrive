package runner

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"syscall"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/mounthelper"
)

// the helper will only ever write inside this directory
const defaultRoot = "/srv/localdrive/external"

// a device name is a plain block device, nothing else is ever accepted
var deviceNamePattern = regexp.MustCompile(`^[a-zA-Z0-9]+$`)

var allowedFilesystems = map[string]string{
	"ext4":  "mkfs.ext4",
	"xfs":   "mkfs.xfs",
	"btrfs": "mkfs.btrfs",
	"exfat": "mkfs.exfat",
	"vfat":  "mkfs.vfat",
}

type helper struct {
	log       *slog.Logger
	secret    string
	root      string
	hasMerger bool
}

// RunMountHelper is the privileged drive helper.
func RunMountHelper(args []string) int {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

	// mount, lsblk and mergerfs are linux tools. on any other host this is not
	// a crash, it is a feature that does not apply, and the server already
	// degrades cleanly when no helper answers.
	if runtime.GOOS != "linux" {
		log.Error("the drive helper only runs on linux",
			"host", runtime.GOOS,
			"note", "manage drives with the host operating system instead")
		return 1
	}

	socket := helperEnvOr("MOUNT_HELPER_SOCKET", "/run/localdrive/mount-helper.sock")
	secret := sharedSecret("MOUNT_HELPER_SHARED_SECRET")
	root := helperEnvOr("EXTERNAL_MOUNTS_PATH", defaultRoot)

	if len(secret) < 16 {
		log.Error("no shared secret available",
			"looked_for", "MOUNT_HELPER_SHARED_SECRET",
			"note", "the server writes one on first start; make sure this "+
				"container can read the database directory")
		return 1
	}
	if err := os.MkdirAll(root, 0o755); err != nil {
		log.Error("could not create the mounts directory", "path", root, "error", err)
		return 1
	}
	if err := os.MkdirAll(filepath.Dir(socket), 0o755); err != nil {
		log.Error("could not create the socket directory", "error", err)
		return 1
	}
	_ = os.Remove(socket)

	h := &helper{log: log, secret: secret, root: filepath.Clean(root)}
	if _, err := exec.LookPath("mergerfs"); err == nil {
		h.hasMerger = true
	} else {
		log.Warn("mergerfs is not installed, combining drives will not be available")
	}

	listener, err := net.Listen("unix", socket)
	if err != nil {
		log.Error("could not listen on the socket", "socket", socket, "error", err)
		return 1
	}
	// the main server container is the only thing that should reach this
	if err := os.Chmod(socket, 0o660); err != nil {
		log.Warn("could not tighten socket permissions", "error", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc(mounthelper.PathHealth, h.authenticated(h.handleHealth))
	mux.HandleFunc(mounthelper.PathList, h.authenticated(h.handleList))
	mux.HandleFunc(mounthelper.PathMount, h.authenticated(h.handleMount))
	mux.HandleFunc(mounthelper.PathUnmount, h.authenticated(h.handleUnmount))
	mux.HandleFunc(mounthelper.PathFormat, h.authenticated(h.handleFormat))
	mux.HandleFunc(mounthelper.PathPool, h.authenticated(h.handlePool))

	server := &http.Server{
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}

	serveErr := make(chan error, 1)
	go func() {
		log.Info("mount helper listening", "socket", socket, "root", h.root, "version", Version)
		if err := server.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	select {
	case err := <-serveErr:
		log.Error("mount helper stopped", "error", err)
		_ = os.Remove(socket)
		return 1
	case <-stop:
	}
	_ = server.Close()
	_ = os.Remove(socket)
	log.Info("mount helper stopped")
	return 0
}

func (h *helper) authenticated(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		provided := r.Header.Get(mounthelper.HeaderSecret)
		if subtle.ConstantTimeCompare([]byte(provided), []byte(h.secret)) != 1 {
			h.log.Warn("rejected a call with a bad secret", "path", r.URL.Path)
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		next(w, r)
	}
}

func (h *helper) handleHealth(w http.ResponseWriter, r *http.Request) {
	helperWriteJSON(w, http.StatusOK, mounthelper.HealthResponse{
		OK: true, Version: Version, MergerFS: h.hasMerger, RootPath: h.root,
	})
}

type lsblkOutput struct {
	BlockDevices []lsblkDevice `json:"blockdevices"`
}

type lsblkDevice struct {
	Name       string        `json:"name"`
	Path       string        `json:"path"`
	Label      string        `json:"label"`
	FSType     string        `json:"fstype"`
	Size       int64         `json:"size"`
	Removable  bool          `json:"rm"`
	MountPoint string        `json:"mountpoint"`
	Model      string        `json:"model"`
	Serial     string        `json:"serial"`
	ReadOnly   bool          `json:"ro"`
	Type       string        `json:"type"`
	Children   []lsblkDevice `json:"children"`
}

func (h *helper) handleList(w http.ResponseWriter, r *http.Request) {
	out, err := helperRun("lsblk", "-J", "-b", "-o",
		"NAME,PATH,LABEL,FSTYPE,SIZE,RM,MOUNTPOINT,MODEL,SERIAL,RO,TYPE")
	if err != nil {
		h.fail(w, err)
		return
	}
	var parsed lsblkOutput
	if err := json.Unmarshal(out, &parsed); err != nil {
		h.fail(w, fmt.Errorf("could not read the device list: %w", err))
		return
	}
	var drives []mounthelper.Drive
	var walk func(devices []lsblkDevice, parentModel string)
	walk = func(devices []lsblkDevice, parentModel string) {
		for _, d := range devices {
			model := d.Model
			if model == "" {
				model = parentModel
			}
			// only leaf partitions and unpartitioned disks are usable
			if len(d.Children) == 0 && (d.Type == "part" || d.Type == "disk") {
				drives = append(drives, mounthelper.Drive{
					ID: d.Name, Path: d.Path, Name: d.Name, Label: d.Label,
					Filesystem: d.FSType, SizeBytes: d.Size, Removable: d.Removable,
					MountPoint: d.MountPoint, Model: strings.TrimSpace(model),
					Serial: d.Serial, ReadOnly: d.ReadOnly,
				})
			}
			walk(d.Children, model)
		}
	}
	walk(parsed.BlockDevices, "")
	helperWriteJSON(w, http.StatusOK, mounthelper.ListResponse{Drives: drives})
}

func (h *helper) handleMount(w http.ResponseWriter, r *http.Request) {
	var req mounthelper.MountRequest
	if !helperReadJSON(w, r, &req) {
		return
	}
	device, err := h.devicePath(req.DeviceID)
	if err != nil {
		h.fail(w, err)
		return
	}
	name := helperSanitizeName(req.Label)
	if name == "" {
		name = helperSanitizeName(req.DeviceID)
	}
	target := filepath.Join(h.root, name)
	if !strings.HasPrefix(target, h.root+string(filepath.Separator)) {
		h.fail(w, errors.New("that mount point is outside the allowed directory"))
		return
	}
	if err := os.MkdirAll(target, 0o755); err != nil {
		h.fail(w, err)
		return
	}
	args := []string{"-o", "noatime,nodev,nosuid,noexec"}
	if req.ReadOnly {
		args = []string{"-o", "ro,noatime,nodev,nosuid,noexec"}
	}
	args = append(args, device, target)
	if _, err := helperRun("mount", args...); err != nil {
		h.fail(w, err)
		return
	}
	fstype := ""
	if out, err := helperRun("findmnt", "-n", "-o", "FSTYPE", "--target", target); err == nil {
		fstype = strings.TrimSpace(string(out))
	}
	h.log.Info("mounted a drive", "device", device, "target", target, "filesystem", fstype)
	helperWriteJSON(w, http.StatusOK, mounthelper.MountResponse{MountPoint: target, Filesystem: fstype})
}

func (h *helper) handleUnmount(w http.ResponseWriter, r *http.Request) {
	var req mounthelper.UnmountRequest
	if !helperReadJSON(w, r, &req) {
		return
	}
	target := filepath.Clean(req.MountPoint)
	if !strings.HasPrefix(target, h.root+string(filepath.Separator)) {
		h.fail(w, errors.New("that mount point is outside the allowed directory"))
		return
	}
	// flush first so the drive is genuinely safe to unplug afterward
	if _, err := helperRun("sync"); err != nil {
		h.log.Warn("sync before unmount failed", "error", err)
	}
	if _, err := helperRun("umount", target); err != nil {
		h.fail(w, err)
		return
	}
	h.log.Info("unmounted a drive", "target", target)
	helperWriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *helper) handleFormat(w http.ResponseWriter, r *http.Request) {
	var req mounthelper.FormatRequest
	if !helperReadJSON(w, r, &req) {
		return
	}
	if req.Confirmation != mounthelper.FormatConfirmation {
		h.fail(w, errors.New("the confirmation phrase does not match"))
		return
	}
	device, err := h.devicePath(req.DeviceID)
	if err != nil {
		h.fail(w, err)
		return
	}
	tool, ok := allowedFilesystems[req.Filesystem]
	if !ok {
		h.fail(w, fmt.Errorf("%q is not a filesystem this helper can create", req.Filesystem))
		return
	}
	// refuse to erase anything currently mounted
	if out, err := helperRun("findmnt", "-n", "-S", device); err == nil && strings.TrimSpace(string(out)) != "" {
		h.fail(w, errors.New("that drive is mounted, eject it first"))
		return
	}
	args := formatArgs(req.Filesystem, helperSanitizeName(req.Label), device)
	if _, err := helperRun(tool, args...); err != nil {
		h.fail(w, err)
		return
	}
	h.log.Warn("formatted a drive", "device", device, "filesystem", req.Filesystem)
	helperWriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func formatArgs(fsName, label, device string) []string {
	var args []string
	if label != "" {
		switch fsName {
		case "ext4":
			args = append(args, "-L", label)
		case "xfs":
			args = append(args, "-L", label, "-f")
		case "btrfs":
			args = append(args, "-L", label, "-f")
		case "exfat":
			args = append(args, "-n", label)
		case "vfat":
			args = append(args, "-n", label)
		}
	} else if fsName == "xfs" || fsName == "btrfs" {
		args = append(args, "-f")
	}
	return append(args, device)
}

func (h *helper) handlePool(w http.ResponseWriter, r *http.Request) {
	var req mounthelper.PoolRequest
	if !helperReadJSON(w, r, &req) {
		return
	}
	if !h.hasMerger {
		h.fail(w, errors.New("mergerfs is not installed in this helper image"))
		return
	}
	if len(req.MountPoints) < 2 {
		h.fail(w, errors.New("a pool needs at least two drives"))
		return
	}
	name := helperSanitizeName(req.Name)
	if name == "" {
		h.fail(w, errors.New("the pool needs a name"))
		return
	}
	var branches []string
	for _, mp := range req.MountPoints {
		clean := filepath.Clean(mp)
		if !strings.HasPrefix(clean, h.root+string(filepath.Separator)) {
			h.fail(w, errors.New("every member must already be mounted under the allowed directory"))
			return
		}
		branches = append(branches, clean)
	}
	target := filepath.Join(h.root, "pools", name)
	if err := os.MkdirAll(target, 0o755); err != nil {
		h.fail(w, err)
		return
	}
	// mfs spreads new files toward whichever member has the most room; this
	// adds capacity only, never redundancy
	options := "defaults,allow_other,use_ino,category.create=mfs,moveonenospc=true,minfreespace=4G"
	if _, err := helperRun("mergerfs", "-o", options, strings.Join(branches, ":"), target); err != nil {
		h.fail(w, err)
		return
	}
	h.log.Info("combined drives into one pool", "target", target, "members", branches)
	helperWriteJSON(w, http.StatusOK, mounthelper.PoolResponse{MountPoint: target})
}

// devicePath turns a device id into an absolute /dev path, rejecting anything
// that is not a plain block device name.
func (h *helper) devicePath(id string) (string, error) {
	id = strings.TrimSpace(id)
	id = strings.TrimPrefix(id, "/dev/")
	if !deviceNamePattern.MatchString(id) {
		return "", fmt.Errorf("%q is not a device name this helper accepts", id)
	}
	path := "/dev/" + id
	info, err := os.Stat(path)
	if err != nil {
		return "", fmt.Errorf("no such device: %s", path)
	}
	if info.Mode()&os.ModeDevice == 0 {
		return "", fmt.Errorf("%s is not a block device", path)
	}
	return path, nil
}

// run executes one fixed argument list. There is no shell anywhere in this
// path, so nothing a caller sends can be interpreted as a command.
func helperRun(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	cmd.Env = []string{"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "LC_ALL=C"}
	out, err := cmd.CombinedOutput()
	if err != nil {
		return out, fmt.Errorf("%s failed: %s", name, strings.TrimSpace(string(out)))
	}
	return out, nil
}

func helperSanitizeName(name string) string {
	var b strings.Builder
	for _, r := range strings.TrimSpace(name) {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == '-' || r == '_':
			b.WriteRune(r)
		case r == ' ':
			b.WriteRune('-')
		}
	}
	out := b.String()
	if len(out) > 48 {
		out = out[:48]
	}
	return strings.Trim(out, "-_")
}

func (h *helper) fail(w http.ResponseWriter, err error) {
	h.log.Warn("operation failed", "error", err)
	helperWriteJSON(w, http.StatusBadRequest, mounthelper.ErrorResponse{Error: err.Error()})
}

func helperWriteJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func helperReadJSON(w http.ResponseWriter, r *http.Request, target any) bool {
	defer r.Body.Close()
	if err := json.NewDecoder(r.Body).Decode(target); err != nil {
		helperWriteJSON(w, http.StatusBadRequest, mounthelper.ErrorResponse{Error: "the request could not be read"})
		return false
	}
	return true
}

func helperEnvOr(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

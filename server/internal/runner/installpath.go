package runner

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// CommandName is what this binary is called once it is on PATH. The release
// asset is named "server", which is a reasonable file name and a poor command
// name.
const CommandName = "localdrive"

// PathInstall is what happened when the binary was put on PATH.
type PathInstall struct {
	// Target is the file that was created.
	Target string
	// ProfileLine is the line appended to a shell profile, empty when the
	// directory was already on PATH.
	ProfileLine string
	// Profile is the file that line went into.
	Profile string
	// AlreadyThere is true when nothing needed doing.
	AlreadyThere bool
}

// OnPath reports whether the command can already be typed from anywhere.
func (p PathInstall) OnPath() bool { return p.Target != "" }

// RunInstallPath is the install-path mode, for anyone who skipped the question
// during setup or moved the binary afterwards.
func RunInstallPath(args []string) int {
	installed, err := InstallOnPath()
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not install "+CommandName+" on your PATH: "+err.Error())
		return 1
	}
	if installed.AlreadyThere {
		fmt.Println(CommandName + " is already installed at " + installed.Target)
		return 0
	}
	fmt.Println("installed " + installed.Target)
	if installed.ProfileLine != "" {
		fmt.Println("added it to your PATH in " + installed.Profile)
		fmt.Println("for this shell only, run: " + installed.ProfileLine)
	}
	return 0
}

// InstallOnPath makes this binary runnable as "localdrive" from any directory.
//
// Root gets /usr/local/bin. Everyone else gets ~/.local/bin, which most
// distributions already have on PATH; when it is not there we add it to the
// shell profile. Either way it works without root.
func InstallOnPath() (PathInstall, error) {
	exe, err := os.Executable()
	if err != nil {
		return PathInstall{}, fmt.Errorf("find this binary: %w", err)
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}

	dir, err := pathInstallDir()
	if err != nil {
		return PathInstall{}, err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return PathInstall{}, fmt.Errorf("create %s: %w", dir, err)
	}

	target := filepath.Join(dir, CommandName)
	if runtime.GOOS == "windows" {
		target += ".exe"
	}

	// installing over itself would delete the binary and leave a link to
	// nothing, which is how a working install turns into a missing command
	if sameFile(target, exe) {
		return PathInstall{Target: target, AlreadyThere: true}, nil
	}

	if err := linkOrCopy(exe, target); err != nil {
		return PathInstall{}, err
	}

	out := PathInstall{Target: target}
	if !dirOnPath(dir) {
		line, profile, err := appendToProfile(dir)
		if err != nil {
			// the binary is installed either way; the shell just has to be
			// told about it, and saying so beats failing the whole setup
			return out, nil
		}
		out.ProfileLine, out.Profile = line, profile
	}
	return out, nil
}

// pathInstallDir picks the first directory this user can actually write to.
func pathInstallDir() (string, error) {
	if runtime.GOOS == "windows" {
		base := os.Getenv("LOCALAPPDATA")
		if base == "" {
			home, err := os.UserHomeDir()
			if err != nil {
				return "", err
			}
			base = home
		}
		return filepath.Join(base, "Programs", CommandName), nil
	}

	if writableDir("/usr/local/bin") {
		return "/usr/local/bin", nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("find your home directory: %w", err)
	}
	return filepath.Join(home, ".local", "bin"), nil
}

// writableDir reports whether a directory exists and takes new files. Checking
// the permission bits is not enough: root in a container, a read only mount and
// SELinux all disagree with them.
func writableDir(dir string) bool {
	info, err := os.Stat(dir)
	if err != nil || !info.IsDir() {
		return false
	}
	probe := filepath.Join(dir, ".localdrive-write-test")
	f, err := os.OpenFile(probe, os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return false
	}
	f.Close()
	os.Remove(probe)
	return true
}

// linkOrCopy prefers a symlink so that updating the binary in place updates
// the command too. Windows needs a privilege for symlinks that a normal
// account does not have, so it gets a copy.
func linkOrCopy(from, to string) error {
	if err := os.Remove(to); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("replace %s: %w", to, err)
	}
	if runtime.GOOS != "windows" {
		if err := os.Symlink(from, to); err == nil {
			return nil
		}
		// a symlink across filesystems or on a filesystem without them is not
		// worth failing over when a copy works
	}
	return copyExecutable(from, to)
}

func copyExecutable(from, to string) error {
	data, err := os.ReadFile(from)
	if err != nil {
		return fmt.Errorf("read %s: %w", from, err)
	}
	if err := os.WriteFile(to, data, 0o755); err != nil {
		return fmt.Errorf("write %s: %w", to, err)
	}
	return nil
}

func sameFile(a, b string) bool {
	ai, err := os.Lstat(a)
	if err != nil {
		return false
	}
	if ai.Mode()&os.ModeSymlink != 0 {
		if resolved, err := filepath.EvalSymlinks(a); err == nil {
			a = resolved
			ai, err = os.Stat(a)
			if err != nil {
				return false
			}
		}
	}
	bi, err := os.Stat(b)
	if err != nil {
		return false
	}
	return os.SameFile(ai, bi)
}

func dirOnPath(dir string) bool {
	clean := filepath.Clean(dir)
	for _, entry := range filepath.SplitList(os.Getenv("PATH")) {
		if entry == "" {
			continue
		}
		if filepath.Clean(entry) == clean {
			return true
		}
	}
	return false
}

// appendToProfile adds the directory to PATH for future shells. It writes to
// the profile the login shell reads, and never twice.
func appendToProfile(dir string) (string, string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", "", err
	}
	profile := filepath.Join(home, ".profile")
	switch {
	case strings.Contains(os.Getenv("SHELL"), "zsh"):
		profile = filepath.Join(home, ".zshrc")
	case fileExists(filepath.Join(home, ".bashrc")):
		profile = filepath.Join(home, ".bashrc")
	}

	line := fmt.Sprintf("export PATH=\"%s:$PATH\"", dir)
	if existing, err := os.ReadFile(profile); err == nil && strings.Contains(string(existing), line) {
		return line, profile, nil
	}

	f, err := os.OpenFile(profile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return "", "", err
	}
	defer f.Close()
	if _, err := fmt.Fprintf(f, "\n# added by localdrive setup\n%s\n", line); err != nil {
		return "", "", err
	}
	return line, profile, nil
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

package runner

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

// Setup promises the command works from anywhere afterwards, and the person
// running it may well not be root. Pointing HOME at a scratch directory keeps
// the test from touching the machine it runs on.
func TestInstallOnPathLandsSomewhereRunnable(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("USERPROFILE", home)
	t.Setenv("LOCALAPPDATA", filepath.Join(home, "AppData", "Local"))

	installed, err := InstallOnPath()
	if err != nil {
		t.Fatalf("install: %v", err)
	}
	if !installed.OnPath() {
		t.Fatal("reported no target, so nothing was installed")
	}

	info, err := os.Lstat(installed.Target)
	if err != nil {
		t.Fatalf("stat %s: %v", installed.Target, err)
	}
	if runtime.GOOS != "windows" && info.Mode()&os.ModeSymlink == 0 {
		if info.Mode().Perm()&0o111 == 0 {
			t.Fatalf("%s is not executable, mode %v", installed.Target, info.Mode())
		}
	}

	// it has to be this binary and not something else. A symlink is the same
	// file; a copy, which is what Windows gets, is a second file with the same
	// contents.
	exe, err := os.Executable()
	if err != nil {
		t.Fatalf("executable: %v", err)
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}
	if info.Mode()&os.ModeSymlink != 0 {
		if !sameFile(installed.Target, exe) {
			t.Fatalf("%s does not resolve to %s", installed.Target, exe)
		}
	} else {
		want, err := os.Stat(exe)
		if err != nil {
			t.Fatalf("stat %s: %v", exe, err)
		}
		got, err := os.Stat(installed.Target)
		if err != nil {
			t.Fatalf("stat %s: %v", installed.Target, err)
		}
		if got.Size() != want.Size() {
			t.Fatalf("%s is %d bytes, the binary is %d", installed.Target, got.Size(), want.Size())
		}
	}

	// running it again is a normal thing to do, and must never leave the
	// person without the binary it was linking to
	if _, err := InstallOnPath(); err != nil {
		t.Fatalf("second install: %v", err)
	}
	if _, err := os.Stat(exe); err != nil {
		t.Fatalf("the original binary is gone after reinstalling: %v", err)
	}
	if _, err := os.Stat(installed.Target); err != nil {
		t.Fatalf("the installed command is gone after reinstalling: %v", err)
	}
}

func TestDirOnPath(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PATH", dir+string(os.PathListSeparator)+"/somewhere/else")
	if !dirOnPath(dir) {
		t.Fatalf("%s is on PATH but was not found there", dir)
	}
	if dirOnPath(filepath.Join(dir, "nested")) {
		t.Fatal("a directory that is not on PATH was reported as on it")
	}
}

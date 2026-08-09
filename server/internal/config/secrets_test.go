package config

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

// A fresh clone with no configuration is the ordinary case, so the server has
// to be able to produce everything it needs on its own.
func TestEnsureSecretsGeneratesWhatIsMissing(t *testing.T) {
	dir := t.TempDir()
	for _, key := range generatedKeys {
		t.Setenv(key, "")
		os.Unsetenv(key)
	}

	created, err := EnsureSecrets(dir)
	if err != nil {
		t.Fatalf("generating secrets failed: %v", err)
	}
	if len(created) != len(generatedKeys) {
		t.Fatalf("expected %d secrets, got %d", len(generatedKeys), len(created))
	}

	for _, key := range generatedKeys {
		value := os.Getenv(key)
		if len(value) < 32 {
			t.Fatalf("%s is %d characters, too short to be useful", key, len(value))
		}
	}

	// written down, because a signing key that changed on every restart would
	// invalidate every token in existence
	raw, err := os.ReadFile(filepath.Join(dir, SecretsFileName))
	if err != nil {
		t.Fatalf("the secrets file was not written: %v", err)
	}
	for _, key := range generatedKeys {
		if !strings.Contains(string(raw), key+"=") {
			t.Fatalf("%s is missing from the secrets file", key)
		}
	}

	// windows has no posix permission bits for chmod to set, so the file
	// relies on the access control list of the directory it sits in instead.
	// the default install directory there is per user.
	if runtime.GOOS != "windows" {
		info, err := os.Stat(filepath.Join(dir, SecretsFileName))
		if err != nil {
			t.Fatal(err)
		}
		if info.Mode().Perm()&0o077 != 0 {
			t.Fatalf("the secrets file is readable by others: %v", info.Mode())
		}
	}
}

func TestEnsureSecretsIsStableAcrossRestarts(t *testing.T) {
	dir := t.TempDir()
	for _, key := range generatedKeys {
		os.Unsetenv(key)
	}
	if _, err := EnsureSecrets(dir); err != nil {
		t.Fatal(err)
	}
	first := os.Getenv("JWT_SECRET")

	// a second start reads what the first one wrote rather than making a new one
	for _, key := range generatedKeys {
		os.Unsetenv(key)
	}
	created, err := EnsureSecrets(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(created) != 0 {
		t.Fatalf("a restart regenerated %v, which would sign everyone out", created)
	}
	if os.Getenv("JWT_SECRET") != first {
		t.Fatal("the signing key changed between starts")
	}
}

func TestEnsureSecretsNeverOverridesTheEnvironment(t *testing.T) {
	dir := t.TempDir()
	mine := strings.Repeat("k", 40)
	t.Setenv("JWT_SECRET", mine)
	os.Unsetenv("MOUNT_HELPER_SHARED_SECRET")
	os.Unsetenv("LAN_DISCOVERY_SHARED_SECRET")

	created, err := EnsureSecrets(dir)
	if err != nil {
		t.Fatal(err)
	}
	if os.Getenv("JWT_SECRET") != mine {
		t.Fatal("an operator's own secret was overwritten")
	}
	for _, key := range created {
		if key == "JWT_SECRET" {
			t.Fatal("a secret that was already set should not be reported as created")
		}
	}
}

func TestTwoMachinesNeverShareASecret(t *testing.T) {
	first := generateSecret("JWT_SECRET")
	second := generateSecret("JWT_SECRET")
	if first == second {
		t.Fatal("two generated secrets collided")
	}
	if len(first) < 32 {
		t.Fatalf("a generated secret is only %d characters", len(first))
	}
}

package config

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
)

// SecretsFileName holds the secrets the server generated for itself, kept
// beside the database rather than in .env, so a person editing configuration
// never has to look at them or worry about pasting one wrong.
const SecretsFileName = "secrets.env"

// The keys that must exist for the server to run, and that nobody should have
// to invent by hand.
var generatedKeys = []string{
	"JWT_SECRET",
	"MOUNT_HELPER_SHARED_SECRET",
	"LAN_DISCOVERY_SHARED_SECRET",
}

// EnsureSecrets fills in any missing secret before configuration is validated.
//
// The point is that `docker compose up` on a fresh clone just works. A person
// who has never used Docker should not meet a wall of warnings about variables
// they have never heard of, and should certainly not be asked to generate
// cryptographic material by hand.
//
// Anything already set in the environment wins, so an operator who does manage
// their own secrets is never overridden.
func EnsureSecrets(dataDir string) (created []string, err error) {
	if err := os.MkdirAll(dataDir, 0o750); err != nil {
		return nil, fmt.Errorf("config: create %s: %w", dataDir, err)
	}
	path := filepath.Join(dataDir, SecretsFileName)

	stored, err := readEnvFile(path)
	if err != nil {
		return nil, err
	}

	changed := false
	for _, key := range generatedKeys {
		// the environment is the authority; this only fills gaps
		if value := strings.TrimSpace(os.Getenv(key)); value != "" {
			continue
		}
		if value, ok := stored[key]; ok && strings.TrimSpace(value) != "" {
			if err := os.Setenv(key, value); err != nil {
				return nil, err
			}
			continue
		}

		value := generateSecret(key)
		stored[key] = value
		created = append(created, key)
		changed = true
		if err := os.Setenv(key, value); err != nil {
			return nil, err
		}
	}

	if changed {
		if err := writeSecretsFile(path, stored); err != nil {
			return nil, err
		}
	}
	return created, nil
}

// generateSecret mixes this machine's own identity into fresh randomness.
//
// The randomness makes it unguessable; the machine identity is what
// makes it distinct from every other install even in the impossible case that
// two machines drew the same bytes. The result is written down, because a
// secret regenerated on every restart would sign tokens nobody could use twice.
func generateSecret(purpose string) string {
	entropy := make([]byte, 48)
	if _, err := rand.Read(entropy); err != nil {
		panic("config: crypto/rand unavailable: " + err.Error())
	}

	mac := hmac.New(sha256.New, entropy)
	mac.Write([]byte(purpose))
	mac.Write([]byte(machineIdentity()))
	sum := mac.Sum(nil)

	// 48 bytes of entropy folded into 32 bytes of digest, encoded, which is
	// comfortably past the 32 character minimum the loader enforces
	return base64.RawURLEncoding.EncodeToString(append(sum, entropy[:16]...))
}

var (
	machineOnce sync.Once
	machineID   string
)

// machineIdentity returns a stable per machine string, or a harmless fallback.
// It is only ever an extra input to a hash, never the secret itself, so a
// machine that cannot report one loses nothing.
func machineIdentity() string {
	machineOnce.Do(func() {
		machineID = readMachineID()
		if machineID == "" {
			host, _ := os.Hostname()
			machineID = "hostname:" + host
		}
	})
	return machineID
}

func readMachineID() string {
	switch runtime.GOOS {
	case "linux":
		for _, path := range []string{"/etc/machine-id", "/var/lib/dbus/machine-id"} {
			if data, err := os.ReadFile(path); err == nil {
				if value := strings.TrimSpace(string(data)); value != "" {
					return value
				}
			}
		}
	case "windows":
		out, err := exec.Command("reg", "query",
			`HKLM\SOFTWARE\Microsoft\Cryptography`, "/v", "MachineGuid").Output()
		if err == nil {
			for _, line := range strings.Split(string(out), "\n") {
				if !strings.Contains(line, "MachineGuid") {
					continue
				}
				fields := strings.Fields(line)
				if len(fields) > 0 {
					return fields[len(fields)-1]
				}
			}
		}
	case "darwin":
		out, err := exec.Command("ioreg", "-rd1", "-c", "IOPlatformExpertDevice").Output()
		if err == nil {
			for _, line := range strings.Split(string(out), "\n") {
				if !strings.Contains(line, "IOPlatformUUID") {
					continue
				}
				if _, value, found := strings.Cut(line, "= "); found {
					return strings.Trim(strings.TrimSpace(value), `"`)
				}
			}
		}
	}
	return ""
}

func readEnvFile(path string) (map[string]string, error) {
	out := map[string]string{}
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return out, nil
		}
		return nil, err
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if key, value, found := strings.Cut(line, "="); found {
			out[strings.TrimSpace(key)] = strings.Trim(strings.TrimSpace(value), `"`)
		}
	}
	return out, nil
}

func writeSecretsFile(path string, values map[string]string) error {
	var b strings.Builder
	b.WriteString("# Generated by Local Drive. Keep this file private.\n")
	b.WriteString("# These were created automatically on first start. Changing one\n")
	b.WriteString("# signs everyone out; deleting the file regenerates them.\n\n")
	for _, key := range generatedKeys {
		if value, ok := values[key]; ok {
			b.WriteString(key + "=" + value + "\n")
		}
	}
	// owner only. on windows there are no posix bits for this to set, so the
	// file relies on the access control list of the directory it sits in; the
	// default install directory there is inside the user's own profile.
	if err := os.WriteFile(path, []byte(b.String()), 0o600); err != nil {
		return err
	}
	return nil
}

// DataDirFor guesses where the secrets file belongs from the database path,
// so a caller does not have to thread a second directory through.
func DataDirFor(dbPath string) string {
	if strings.TrimSpace(dbPath) == "" {
		return "."
	}
	return filepath.Dir(dbPath)
}

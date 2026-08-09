package runner

import (
	"bytes"
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// The day to day controls. Each one works the same whether the install runs
// under Docker or directly on the machine, so nobody has to remember which
// kind they made.

// RunStart brings a configured server up.
func RunStart(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}
	if !install.Exists() {
		return failf("no server is set up at %s. run: localdrive setup", install.Dir)
	}

	// a compose file is written at init time whether or not Docker is ever
	// used, so its presence says nothing about how this server actually runs.
	// Asking Docker what it has running is the only answer that cannot be wrong.
	if underDocker(install) {
		if err := compose(install, "up", "-d"); err != nil {
			return fail(err)
		}
		setupOk("started")
		return reportAddresses(install)
	}

	// a registered service already owns this server, so starting a second copy
	// in this window would only fight it for the port
	if ServiceManaged() {
		if err := ControlService("start"); err != nil {
			return fail(err)
		}
		setupOk("started")
		return reportAddresses(install)
	}

	fmt.Println()
	fmt.Println("  This install runs directly on this machine, with no Docker.")
	fmt.Println("  Starting it in this window. Close the window or press Ctrl+C to stop.")
	fmt.Println()
	return RunServer(args)
}

// RunStop takes a running server down.
func RunStop(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}
	if !underDocker(install) {
		if ServiceManaged() {
			if err := ControlService("stop"); err != nil {
				return fail(err)
			}
			setupOk("stopped")
			return 0
		}
		return failf("this install runs in the foreground, so stop it in the window it is running in")
	}
	if err := compose(install, "down"); err != nil {
		return fail(err)
	}
	setupOk("stopped")
	return 0
}

// RunRestart is stop then start, which is also what picks up a changed setting.
func RunRestart(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}
	if !underDocker(install) {
		// a service holds the process, so restarting it is what picks up a new
		// binary after an update or a changed setting
		if ServiceManaged() {
			if err := ControlService("restart"); err != nil {
				return fail(err)
			}
			setupOk("restarted")
			return 0
		}
		return failf("this install runs in the foreground, so restart it in the window it is running in")
	}
	if err := compose(install, "restart"); err != nil {
		return fail(err)
	}
	setupOk("restarted")
	return 0
}

// RunLogs follows the server log.
func RunLogs(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}
	if !underDocker(install) {
		if ServiceManaged() && runtime.GOOS == "linux" {
			cmd := exec.Command("journalctl", "-u", ServiceUnitName, "-f", "-n", "200")
			cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
			if err := cmd.Run(); err != nil {
				return fail(err)
			}
			return 0
		}
		return failf("this install prints its log in the window it runs in")
	}
	cmd := exec.Command("docker", "compose", "logs", "-f", "--tail", "200")
	cmd.Dir = install.Dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fail(err)
	}
	return 0
}

// RunStatus says whether the server is up and where to reach it, which is the
// question someone actually has.
func RunStatus(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}
	setupHeader()

	if !install.Exists() {
		fmt.Printf("  No server is set up at %s\n", install.Dir)
		fmt.Println("  Run: localdrive setup")
		fmt.Println()
		return 1
	}

	env := install.ReadEnv()
	port := install.Port()
	domain := env["LD_DOMAIN"]

	fmt.Printf("  Install     %s\n", install.Dir)
	fmt.Printf("  Data        %s\n", firstNonEmpty(env["DATA_DIR"], install.DataDir))
	fmt.Printf("  Port        %d\n", port)
	if domain != "" {
		fmt.Printf("  Domain      %s\n", domain)
	}
	fmt.Printf("  Mode        %s\n", modeName(install))
	fmt.Println()

	reachable, detail := probeHealth(port)
	if reachable {
		fmt.Println("  Running")
	} else {
		fmt.Printf("  Not answering (%s)\n", detail)
		if install.HasCompose() {
			fmt.Println("  Try: localdrive start")
		}
	}
	fmt.Println()
	return reportAddresses(install)
}

// RunBackup copies the database and the library somewhere safe. The database
// copy is taken with the server still serving, which is safe because sqlite's
// own online backup is what does the copying.
func RunBackup(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}
	if !install.Exists() {
		return failf("no server is set up at %s", install.Dir)
	}

	dest := ""
	for i, arg := range args {
		if !strings.HasPrefix(arg, "-") {
			dest = args[i]
			break
		}
	}
	if dest == "" {
		dest = filepath.Join(install.Dir, "backups")
	}
	stamp := time.Now().Format("20060102-150405")
	target := filepath.Join(dest, stamp)
	if err := os.MkdirAll(target, 0o750); err != nil {
		return fail(err)
	}

	env := install.ReadEnv()
	dataDir := firstNonEmpty(env["DATA_DIR"], install.DataDir)

	setupStep("Backing up")
	if err := copyTree(filepath.Join(dataDir, "db"), filepath.Join(target, "db")); err != nil {
		return fail(fmt.Errorf("copy the database: %w", err))
	}
	setupOk("database")
	if err := copyTree(filepath.Join(dataDir, "library"), filepath.Join(target, "library")); err != nil {
		return fail(fmt.Errorf("copy the library: %w", err))
	}
	setupOk("library")

	fmt.Println()
	fmt.Println("  Backup written to " + target)
	fmt.Println()
	fmt.Println("  To restore: stop the server, put db/ and library/ back where they")
	fmt.Println("  came from under " + dataDir + ", then start it again.")
	fmt.Println()
	return 0
}

// modeName reports how the server is actually running, not how it could be.
// A docker-compose.yml is written at init time whether or not Docker is ever
// used, so its presence on disk proves nothing: asking Docker what it has
// running is the only answer that cannot be wrong.
func modeName(install Install) string {
	if underDocker(install) {
		return "docker compose"
	}
	return "directly on this machine"
}

// underDocker reports whether the running server is the one in the container,
// which decides both the mode line and whether the addresses are https.
func underDocker(install Install) bool {
	return install.HasCompose() && composeRunning(install)
}

// composeRunning reports whether this install has a container up. Any failure
// counts as no, which covers Docker not being installed, not running, or not
// permitting this user, without any of them needing a separate check.
func composeRunning(install Install) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "docker", "compose", "ps", "--status", "running", "--quiet")
	cmd.Dir = install.Dir
	out, err := cmd.Output()
	return err == nil && len(bytes.TrimSpace(out)) > 0
}

func reportAddresses(install Install) int {
	env := install.ReadEnv()
	port := install.Port()
	domain := env["LD_DOMAIN"]

	kind := TLSKindFor(domain, env["LD_TLS"], underDocker(install))

	fmt.Println("  Open one of these:")
	for _, address := range ServerAddresses(domain, port, kind) {
		fmt.Println("    " + address)
	}
	if note := AddressNote(domain, kind); note != "" {
		fmt.Println()
		fmt.Println("  " + note)
	}
	fmt.Println()
	return 0
}

// probeHealth asks the server whether it is up, over loopback, so this works
// the same on a machine with no name resolution for its own address.
func probeHealth(port int) (bool, string) {
	client := &http.Client{
		Timeout: 4 * time.Second,
		Transport: &http.Transport{
			// this only ever talks to loopback, and a fresh install has a
			// certificate it issued to itself
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, // #nosec G402
		},
	}
	for _, scheme := range []string{"https", "http"} {
		url := fmt.Sprintf("%s://127.0.0.1:%d/healthz", scheme, port)
		resp, err := client.Get(url)
		if err != nil {
			continue
		}
		resp.Body.Close()
		if resp.StatusCode == http.StatusOK {
			return true, ""
		}
	}
	return false, fmt.Sprintf("nothing on port %d", port)
}

func compose(install Install, args ...string) error {
	state, _ := CheckDocker()
	if state != DockerReady {
		for _, line := range ExplainDocker(state) {
			if line == "" {
				fmt.Println()
				continue
			}
			fmt.Println("    " + line)
		}
		return fmt.Errorf("the Docker engine is not reachable, %s", dockerHint())
	}
	full := append([]string{"compose"}, args...)
	cmd := exec.Command("docker", full...)
	cmd.Dir = install.Dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// copyTree copies a directory, which is all the backup needs and avoids
// depending on rsync existing, since it does not on Windows.
func copyTree(from, to string) error {
	info, err := os.Stat(from)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	if !info.IsDir() {
		return copyOneFile(from, to)
	}
	if err := os.MkdirAll(to, 0o750); err != nil {
		return err
	}
	entries, err := os.ReadDir(from)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		source := filepath.Join(from, entry.Name())
		dest := filepath.Join(to, entry.Name())
		if entry.IsDir() {
			if err := copyTree(source, dest); err != nil {
				return err
			}
			continue
		}
		// a write ahead log alongside the database is part of it, so both go
		if err := copyOneFile(source, dest); err != nil {
			return err
		}
	}
	return nil
}

func copyOneFile(from, to string) error {
	data, err := os.ReadFile(from)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(to), 0o750); err != nil {
		return err
	}
	return os.WriteFile(to, data, 0o640)
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func fail(err error) int {
	fmt.Fprintln(os.Stderr)
	fmt.Fprintln(os.Stderr, "  "+err.Error())
	fmt.Fprintln(os.Stderr)
	return 1
}

func failf(format string, args ...any) int {
	return fail(fmt.Errorf(format, args...))
}

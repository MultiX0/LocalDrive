package runner

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	qrcode "github.com/skip2/go-qrcode"
	"golang.org/x/term"

	"github.com/MultiX0/LocalDrive/server/internal/auth"
)

// RunSetup is the interactive installer.
func RunSetup(args []string) int {
	if err := doSetup(args); err != nil {
		fmt.Fprintln(os.Stderr)
		fmt.Fprintln(os.Stderr, "  Setup stopped: "+err.Error())
		fmt.Fprintln(os.Stderr)
		return 1
	}
	return 0
}

// RunResetAdmin recovers a locked-out admin.
func RunResetAdmin(args []string) int {
	if err := doResetAdmin(args); err != nil {
		fmt.Fprintln(os.Stderr)
		fmt.Fprintln(os.Stderr, "  Reset stopped: "+err.Error())
		fmt.Fprintln(os.Stderr)
		return 1
	}
	return 0
}

func setupHeader() {
	fmt.Println()
	fmt.Println("  Local Drive")
	fmt.Println("  Your own file server, on your own hardware.")
	fmt.Println("  ------------------------------------------")
	fmt.Println()
}

func doSetup(args []string) error {
	setupHeader()
	in := bufio.NewReader(os.Stdin)

	install, err := FindInstall(args)
	if err != nil {
		return err
	}

	// 1. where everything lives
	setupStep("Where should Local Drive keep everything")
	dir := setupAsk(in, "Folder", install.Dir)
	install.Dir, err = filepath.Abs(dir)
	if err != nil {
		return err
	}
	install.EnvPath = filepath.Join(install.Dir, ".env")
	install.DataDir = filepath.Join(install.Dir, "data")
	if err := os.MkdirAll(install.DataDir, 0o750); err != nil {
		return fmt.Errorf("could not create %s: %w", install.DataDir, err)
	}
	setupOk("Using " + install.Dir)

	if install.Exists() {
		fmt.Println()
		fmt.Println("  There is already a server configured here.")
		if !setupConfirm(in, "Reconfigure it") {
			fmt.Println()
			fmt.Println("  Nothing changed. To start it: localdrive start")
			fmt.Println()
			return nil
		}
	}

	// 2. how it will run. running directly is the default: it is one process
	// instead of three, it starts faster and it uses noticeably less memory,
	// which is the difference between comfortable and not on a small machine.
	// docker is offered because it adds the proxy, drive management and
	// network discovery, none of which the bare binary can do alone.
	setupStep("How should it run")
	useDocker := false
	if EnsureDocker(true) {
		fmt.Println("    Docker is installed and running.")
		fmt.Println()
		fmt.Println("    Running directly is lighter and is the default. Docker adds")
		fmt.Println("    https, drive management and network discovery.")
		useDocker = !setupConfirm(in, "Run it directly on this machine (recommended)")
	} else {
		fmt.Println()
		fmt.Println("    Local Drive will run directly on this machine.")
		if !setupConfirm(in, "Run it directly on this machine") {
			return errors.New("nothing to do then; install Docker and run this again")
		}
	}
	setupOk(map[bool]string{true: "Using Docker", false: "Running directly on this machine"}[useDocker])

	// 3. the port. not 443: a self-hosted machine usually has other things on
	// it, and 443 is the first port anything else will want.
	setupStep("Which port should it serve on")
	port := DefaultPort
	for {
		raw := setupAsk(in, "Port", strconv.Itoa(DefaultPort))
		parsed, convErr := strconv.Atoi(raw)
		if convErr != nil || parsed < 1 || parsed > 65535 {
			fmt.Println("    That is not a usable port number.")
			continue
		}
		if !PortAvailable(parsed) {
			fmt.Printf("    Port %d is already in use on this machine. Pick another one.\n", parsed)
			continue
		}
		port = parsed
		break
	}
	setupOk(fmt.Sprintf("Serving on port %d", port))

	// 4. a domain, only if they actually have one. the ordinary case is an
	// address on the local network, and this must not pretend otherwise.
	setupStep("Do you have a domain name for this server")
	fmt.Println("    Most people do not, and do not need one. Leave this empty and")
	fmt.Println("    Local Drive is reached at this machine's address on your network.")
	fmt.Println()
	domain := strings.TrimSpace(setupAsk(in, "Domain (leave empty for none)", ""))
	tlsEmail := ""
	if domain != "" {
		fmt.Println()
		fmt.Println("    A certificate authority can send renewal notices. This is optional.")
		tlsEmail = strings.TrimSpace(setupAsk(in, "Email for certificate notices (optional)", ""))
		setupOk("Using " + domain)
	} else {
		setupOk("No domain, which is the normal case")
	}

	// 5. the admin account
	setupStep("Create the admin account")
	fmt.Println("    This is the account you sign in with. You can skip it and use a")
	fmt.Println("    temporary login instead, which has to be changed before anything")
	fmt.Println("    else works.")
	fmt.Println()

	username := setupAsk(in, "Admin username", "admin")
	password := ""
	skipAccount := false
	for {
		password = setupAskSecret("Admin password (leave empty to skip)")
		if password == "" {
			if setupConfirm(in, "Skip and use a temporary login") {
				skipAccount = true
				break
			}
			continue
		}
		if err := auth.ValidatePassword(password); err != nil {
			fmt.Println("    " + err.Error())
			continue
		}
		if setupAskSecret("Type it once more") != password {
			fmt.Println("    Those did not match.")
			continue
		}
		break
	}
	serverName := setupAsk(in, "What should this server be called", "Local Drive")

	// 6. every secret, generated, never blank and never a placeholder
	setupStep("Writing configuration")
	proxy := ProxyConfig{Port: port, Domain: domain, TLSEmail: tlsEmail}
	env := map[string]string{
		"LD_PORT":                         strconv.Itoa(port),
		"LD_DOMAIN":                       domain,
		"LD_TLS_EMAIL":                    tlsEmail,
		"APP_ENV":                         "production",
		"LOG_LEVEL":                       "info",
		"DATA_DIR":                        filepath.ToSlash(install.DataDir),
		"ACCESS_TOKEN_TTL":                "15m",
		"REFRESH_TOKEN_TTL":               "30d",
		"MAX_UPLOAD_CONCURRENCY":          "4",
		"WORKER_POOL_SIZE":                "2",
		"DEFAULT_QUOTA_BYTES":             "0",
		"TRASH_RETENTION_DAYS":            "30",
		"VERSION_RETENTION_COUNT":         "20",
		"VERSION_RETENTION_DAYS":          "180",
		"ENABLE_LAN_DISCOVERY_DEFAULT":    "true",
		"REQUIRE_DEVICE_APPROVAL_DEFAULT": "true",
		"ALLOW_SELF_REGISTRATION_DEFAULT": "false",
		"PUBLIC_BASE_URL":                 proxy.BaseURL(),
		"JWT_SECRET":                      setupSecret(48),
		"MOUNT_HELPER_SHARED_SECRET":      setupSecret(32),
		"LAN_DISCOVERY_SHARED_SECRET":     setupSecret(32),
	}

	if useDocker {
		env["LISTEN_ADDR"] = fmt.Sprintf(":%d", InternalPort)
		env["DB_PATH"] = "/data/db/localdrive.sqlite"
		env["LIBRARY_PATH"] = "/data/library"
		env["EXTERNAL_MOUNTS_PATH"] = "/data/external"
		env["EXTERNAL_MOUNTS_HOST"] = filepath.ToSlash(filepath.Join(install.DataDir, "external"))
		env["MOUNT_HELPER_SOCKET"] = "/run/localdrive/mount-helper.sock"
		env["LAN_DISCOVERY_SOCKET"] = "/run/localdrive-discovery/lan-discovery.sock"
	} else {
		// running directly, so it binds the real port itself and serves plain
		// http; there is no proxy in front to terminate tls
		env["LISTEN_ADDR"] = fmt.Sprintf(":%d", port)
		env["DB_PATH"] = filepath.ToSlash(filepath.Join(install.DataDir, "db", "localdrive.sqlite"))
		env["LIBRARY_PATH"] = filepath.ToSlash(filepath.Join(install.DataDir, "library"))
		env["EXTERNAL_MOUNTS_PATH"] = filepath.ToSlash(filepath.Join(install.DataDir, "external"))
		// the two helpers are a Docker arrangement; without it there is
		// nothing to talk to, and the server degrades cleanly
		env["MOUNT_HELPER_SOCKET"] = ""
		env["LAN_DISCOVERY_SOCKET"] = ""
	}

	if err := WriteEnvFile(install.EnvPath, env); err != nil {
		return err
	}
	setupOk("Wrote " + install.EnvPath)

	if useDocker {
		if wrote, err := writeIfAbsent(install.CaddyfilePath(), RenderCaddyfile(proxy)); err != nil {
			return err
		} else if wrote {
			setupOk("Wrote " + install.CaddyfilePath())
		}
		compose := RenderCompose(proxy, install.DataDir, env["EXTERNAL_MOUNTS_HOST"])
		if wrote, err := writeIfAbsent(install.ComposePath(), compose); err != nil {
			return err
		} else if wrote {
			setupOk("Wrote " + install.ComposePath())
		}
	}

	// 7. bring it up and wait for it to actually answer
	// https only when a domain is set, since that is the only case where caddy
	// has a certificate. otherwise it is listening on plain http and asking
	// for https here would fail the handshake before the request went out
	scheme := "http"
	if domain != "" {
		scheme = "https"
	}
	baseURL := fmt.Sprintf("%s://127.0.0.1:%d", scheme, port)
	if useDocker {
		setupStep("Starting Local Drive")
		if err := setupComposeUp(install); err != nil {
			return err
		}
		if err := setupWaitForHealth(port); err != nil {
			return err
		}
		setupOk("The server is up")
	} else {
		baseURL = fmt.Sprintf("http://127.0.0.1:%d", port)
		fmt.Println()
		fmt.Println("  Start it whenever you like with:")
		fmt.Println()
		fmt.Println("      localdrive start")
		fmt.Println()
	}

	// 8. create the real account now, so it exists before anyone opens the app
	if !skipAccount && useDocker {
		setupStep("Creating your account")
		if err := setupCallSetup(baseURL, username, password, serverName); err != nil {
			return err
		}
		setupOk("Signed up as " + username)
	} else if skipAccount {
		fmt.Println()
		fmt.Println("  The temporary login is admin / admin12345.")
		fmt.Println("  Change it the first time you open the app. Nothing else works")
		fmt.Println("  until you do.")
	}

	// 9. where to go, including from a phone
	setupStep("You are ready")
	addresses := LANAddresses(port, domain != "")
	if domain != "" {
		addresses = append([]string{proxy.BaseURL()}, addresses...)
	}
	for _, address := range addresses {
		fmt.Println("    " + address)
	}
	if len(addresses) > 0 {
		fmt.Println()
		setupPrintQR(addresses[0])
	}
	fmt.Println()
	fmt.Println("  Open one of those, or scan the code above from a phone.")
	if domain == "" {
		fmt.Println()
		fmt.Println("  This is plain http. On your own network that is usually what you")
		fmt.Println("  want, since no certificate authority will issue for an ip address.")
		fmt.Println("  If you are reaching this server from outside, point a domain at it")
		fmt.Println("  and set LD_DOMAIN in .env for real https.")
	}
	fmt.Println()
	fmt.Println("  localdrive status    where it is and whether it is up")
	fmt.Println("  localdrive logs      follow the log")
	fmt.Println("  localdrive stop      stop it")
	fmt.Println()
	return nil
}

func doResetAdmin(args []string) error {
	setupHeader()
	in := bufio.NewReader(os.Stdin)

	install, err := FindInstall(args)
	if err != nil {
		return err
	}
	setupStep("Reset the admin password")
	dir := setupAsk(in, "Install folder", install.Dir)
	install.Dir, err = filepath.Abs(dir)
	if err != nil {
		return err
	}
	install.EnvPath = filepath.Join(install.Dir, ".env")
	install.DataDir = filepath.Join(install.Dir, "data")

	env := install.ReadEnv()
	dataDir := firstNonEmpty(env["DATA_DIR"], install.DataDir)
	dbDir := filepath.Join(dataDir, "db")
	if _, err := os.Stat(dbDir); err != nil {
		return fmt.Errorf("no Local Drive data found at %s", dbDir)
	}

	username := setupAsk(in, "Which account (leave empty for the first admin)", "")
	password := setupAskSecret("New password (leave empty to generate one)")
	if password == "" {
		password = setupSecret(9)
	}
	if err := auth.ValidatePassword(password); err != nil {
		return err
	}

	// the server is the only thing that ever writes to its own database, so
	// this drops a marker it consumes on startup rather than touching sqlite
	marker := auth.RecoveryMarker{
		Password:  password,
		Username:  strings.TrimSpace(username),
		CreatedAt: time.Now().UnixMilli(),
	}
	encoded, err := json.MarshalIndent(marker, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(dbDir, auth.RecoveryMarkerName), encoded, 0o600); err != nil {
		return err
	}
	setupOk("Wrote the recovery request")

	if install.HasCompose() {
		setupStep("Restarting the server")
		if err := compose(install, "restart", "server"); err != nil {
			return err
		}
		setupOk("Restarted")
	} else {
		fmt.Println()
		fmt.Println("  Restart the server to apply it.")
	}

	fmt.Println()
	fmt.Println("  The password is now:")
	fmt.Println()
	fmt.Println("      " + password)
	fmt.Println()
	fmt.Println("  You will be asked to choose a new one when you sign in.")
	fmt.Println()
	return nil
}

// host checks

func setupComposeUp(install Install) error {
	cmd := exec.Command("docker", "compose", "up", "-d", "--build")
	cmd.Dir = install.Dir
	return setupRunWithProgress(cmd, "Building and starting")
}

// setupRunWithProgress shows a moving indicator instead of a wall of container
// logs, and only prints the log if something actually failed.
func setupRunWithProgress(cmd *exec.Cmd, label string) error {
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output

	if err := cmd.Start(); err != nil {
		return err
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()

	frames := []string{".  ", ".. ", "..."}
	ticker := time.NewTicker(400 * time.Millisecond)
	defer ticker.Stop()
	frame := 0
	for {
		select {
		case err := <-done:
			fmt.Printf("\r    %s ... done      \n", label)
			if err != nil {
				fmt.Println()
				fmt.Println(strings.TrimSpace(output.String()))
				return fmt.Errorf("%s failed", label)
			}
			return nil
		case <-ticker.C:
			fmt.Printf("\r    %s %s", label, frames[frame%len(frames)])
			frame++
		}
	}
}

func setupWaitForHealth(port int) error {
	deadline := time.Now().Add(3 * time.Minute)
	for time.Now().Before(deadline) {
		if up, _ := probeHealth(port); up {
			fmt.Print("\r                                        \r")
			return nil
		}
		fmt.Print("\r    Waiting for the server to answer ...")
		time.Sleep(2 * time.Second)
	}
	fmt.Println()
	return errors.New("the server did not come up in time, check: localdrive logs")
}

func setupCallSetup(baseURL, username, password, serverName string) error {
	body, err := json.Marshal(map[string]string{
		"username":    username,
		"password":    password,
		"server_name": serverName,
		"device_name": "Setup",
		"platform":    runtime.GOOS,
	})
	if err != nil {
		return err
	}
	client := &http.Client{
		Timeout:   20 * time.Second,
		Transport: &http.Transport{TLSClientConfig: insecureLocalTLS()},
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/api/v1/setup", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusConflict {
		return errors.New("this server already has an account, use: localdrive reset-admin")
	}
	if resp.StatusCode >= 400 {
		var payload map[string]any
		_ = json.NewDecoder(resp.Body).Decode(&payload)
		return fmt.Errorf("the server refused the account: %v", payload)
	}
	return nil
}

// output helpers

func setupStep(label string) {
	fmt.Println()
	fmt.Println("  " + label)
}

func setupOk(message string) { fmt.Println("    " + message) }

func setupAsk(in *bufio.Reader, prompt, def string) string {
	if def != "" {
		fmt.Printf("  %s [%s]: ", prompt, def)
	} else {
		fmt.Printf("  %s: ", prompt)
	}
	line, err := in.ReadString('\n')
	if err != nil {
		return def
	}
	line = strings.TrimSpace(line)
	if line == "" {
		return def
	}
	return line
}

func setupAskSecret(prompt string) string {
	fmt.Printf("  %s: ", prompt)
	fd := int(os.Stdin.Fd())
	if !term.IsTerminal(fd) {
		reader := bufio.NewReader(os.Stdin)
		line, _ := reader.ReadString('\n')
		return strings.TrimSpace(line)
	}
	raw, err := term.ReadPassword(fd)
	fmt.Println()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(raw))
}

func setupConfirm(in *bufio.Reader, prompt string) bool {
	answer := strings.ToLower(setupAsk(in, prompt+" (y/n)", "y"))
	return answer == "y" || answer == "yes"
}

func setupSecret(bytesLen int) string {
	buf := make([]byte, bytesLen)
	if _, err := rand.Read(buf); err != nil {
		panic("crypto/rand unavailable: " + err.Error())
	}
	return base64.RawURLEncoding.EncodeToString(buf)
}

func setupPrintQR(target string) {
	code, err := qrcode.New(target, qrcode.Low)
	if err != nil {
		return
	}
	fmt.Print(code.ToSmallString(false))
}

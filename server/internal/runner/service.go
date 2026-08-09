package runner

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// ServiceUnitName is what the unit, job or task is called on each platform.
const ServiceUnitName = "localdrive"

// Registers the server with whatever the machine already uses to start things
// at boot, rather than writing a background mode of our own:
//
//	linux    systemd, a user unit when not root so it needs no privileges
//	macos    launchd
//	windows  the task scheduler, at logon
//
// Every one of them runs "localdrive serve" against a fixed install directory,
// so the service does not depend on which directory it was installed from.

// RunServiceInstall is the "service" mode, for anyone who said no during setup
// or who set the server up before this existed.
func RunServiceInstall(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}
	status, err := InstallService(install)
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not install the service: "+err.Error())
		if !status.Supported {
			fmt.Fprintln(os.Stderr, "see the manual steps in docs/self-hosting/running-always.mdx")
		}
		return 1
	}
	PrintServiceResult(status)
	return 0
}

// PrintServiceResult reports what was registered, in the same words whether it
// came from setup or from the standalone command.
func PrintServiceResult(status ServiceStatus) {
	if status.Unit != "" {
		fmt.Println("    Registered with " + status.Manager + ": " + status.Unit)
	}
	if status.Running {
		fmt.Println("    It is running now and will come back after a reboot.")
	} else if status.Installed {
		fmt.Println("    It will start at boot.")
	}
	if status.Detail != "" {
		fmt.Println("    " + status.Detail)
	}
}

// ServiceStatus is what the machine thinks of the service right now.
type ServiceStatus struct {
	Supported bool
	Installed bool
	Running   bool
	Manager   string
	Unit      string
	Detail    string
}

// InstallService registers the server to start at boot and starts it now.
func InstallService(install Install) (ServiceStatus, error) {
	exe, err := serviceBinary()
	if err != nil {
		return ServiceStatus{}, err
	}
	switch runtime.GOOS {
	case "linux":
		return installSystemd(install, exe)
	case "darwin":
		return installLaunchd(install, exe)
	case "windows":
		return installScheduledTask(install, exe)
	}
	return ServiceStatus{Supported: false}, fmt.Errorf("no service manager is known for %s", runtime.GOOS)
}

// serviceBinary is the path the service will run. It has to be absolute and it
// has to still be there after the shell that ran setup is gone, so a relative
// "./server" is resolved here rather than written into the unit.
func serviceBinary() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("find this binary: %w", err)
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}
	return filepath.Abs(exe)
}

// ---------------------------------------------------------------- linux

func installSystemd(install Install, exe string) (ServiceStatus, error) {
	root := os.Geteuid() == 0
	unitDir := "/etc/systemd/system"
	args := []string{}
	if !root {
		home, err := os.UserHomeDir()
		if err != nil {
			return ServiceStatus{}, err
		}
		unitDir = filepath.Join(home, ".config", "systemd", "user")
		args = append(args, "--user")
	}
	if err := os.MkdirAll(unitDir, 0o755); err != nil {
		return ServiceStatus{}, fmt.Errorf("create %s: %w", unitDir, err)
	}

	unitPath := filepath.Join(unitDir, ServiceUnitName+".service")
	if err := os.WriteFile(unitPath, []byte(systemdUnit(install, exe, root)), 0o644); err != nil {
		return ServiceStatus{}, fmt.Errorf("write %s: %w", unitPath, err)
	}

	status := ServiceStatus{Supported: true, Manager: "systemd", Unit: unitPath}
	if _, err := exec.LookPath("systemctl"); err != nil {
		status.Detail = "systemctl was not found, so the unit was written but not started"
		return status, nil
	}

	run := func(a ...string) error {
		cmd := exec.Command("systemctl", append(args, a...)...)
		out, err := cmd.CombinedOutput()
		if err != nil {
			return fmt.Errorf("systemctl %s: %s", strings.Join(a, " "), strings.TrimSpace(string(out)))
		}
		return nil
	}
	if err := run("daemon-reload"); err != nil {
		return status, err
	}
	if err := run("enable", ServiceUnitName+".service"); err != nil {
		return status, err
	}
	if err := run("restart", ServiceUnitName+".service"); err != nil {
		return status, err
	}
	status.Installed = true

	// systemctl returning 0 means the unit was asked to start, not that it is
	// still up. With Restart=always a server that cannot bind its port fails
	// and respawns forever, and reporting that as running is how someone walks
	// away from a machine that is not serving anything.
	status.Running = systemdSettled(args)
	if !status.Running {
		status.Detail = "it did not stay up. `journalctl -u " + ServiceUnitName +
			" -n 30` says why; a port already in use is the usual cause"
	}

	if !root {
		// without this the user's services stop at logout, which on a server
		// reached over ssh means the moment the session ends
		if err := exec.Command("loginctl", "enable-linger", os.Getenv("USER")).Run(); err != nil {
			status.Detail = "run `sudo loginctl enable-linger $USER` so it keeps running after you log out"
		}
	}
	return status, nil
}

// systemdSettled waits for the unit to either hold or fail. A unit that is
// respawning reads as "activating" rather than "failed", so waiting for one
// state and not the other would hang on the case worth catching.
func systemdSettled(args []string) bool {
	for range 10 {
		time.Sleep(500 * time.Millisecond)
		out, _ := exec.Command("systemctl", append(args, "is-active", ServiceUnitName+".service")...).Output()
		switch strings.TrimSpace(string(out)) {
		case "active":
			// still up a moment later, rather than up for an instant
			time.Sleep(1500 * time.Millisecond)
			again, _ := exec.Command("systemctl", append(args, "is-active", ServiceUnitName+".service")...).Output()
			return strings.TrimSpace(string(again)) == "active"
		case "failed", "inactive":
			return false
		}
	}
	return false
}

func systemdUnit(install Install, exe string, root bool) string {
	var b strings.Builder
	b.WriteString("# Generated by localdrive. Safe to edit; localdrive service install\n")
	b.WriteString("# overwrites it.\n\n")
	b.WriteString("[Unit]\n")
	b.WriteString("Description=Local Drive, your own file server\n")
	b.WriteString("After=network-online.target\n")
	b.WriteString("Wants=network-online.target\n")
	// systemd gives up after 5 restarts in 10 seconds by default and leaves the
	// unit failed. That is the opposite of what is wanted here: a server that
	// cannot bind its port yet because the network is slow coming up would be
	// abandoned a few seconds into a boot and stay down until someone noticed.
	b.WriteString("StartLimitIntervalSec=0\n\n")

	b.WriteString("[Service]\n")
	fmt.Fprintf(&b, "ExecStart=%s serve --dir %s\n", exe, install.Dir)
	b.WriteString("Restart=always\n")
	b.WriteString("RestartSec=5\n")
	// a file server holds a descriptor per open file, per upload and per
	// websocket at once. The usual 1024 is a ceiling a busy server reaches.
	b.WriteString("LimitNOFILE=65535\n")
	// let downloads and uploads in flight finish rather than cutting them
	b.WriteString("TimeoutStopSec=30\n")
	// a certificate needs 443, and a service is not a login shell, so grant the
	// one capability rather than asking for the whole of root
	if root {
		b.WriteString("AmbientCapabilities=CAP_NET_BIND_SERVICE\n")
		b.WriteString("CapabilityBoundingSet=CAP_NET_BIND_SERVICE\n")
		b.WriteString("NoNewPrivileges=true\n")
	}
	b.WriteString("\n[Install]\n")
	if root {
		b.WriteString("WantedBy=multi-user.target\n")
	} else {
		b.WriteString("WantedBy=default.target\n")
	}
	return b.String()
}

// ---------------------------------------------------------------- macos

func installLaunchd(install Install, exe string) (ServiceStatus, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return ServiceStatus{}, err
	}
	dir := filepath.Join(home, "Library", "LaunchAgents")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return ServiceStatus{}, fmt.Errorf("create %s: %w", dir, err)
	}
	label := "dev.localdrive." + ServiceUnitName
	plistPath := filepath.Join(dir, label+".plist")

	plist := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>%s</string>
  <key>ProgramArguments</key>
  <array>
    <string>%s</string><string>serve</string><string>--dir</string><string>%s</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
`, label, exe, install.Dir)

	if err := os.WriteFile(plistPath, []byte(plist), 0o644); err != nil {
		return ServiceStatus{}, fmt.Errorf("write %s: %w", plistPath, err)
	}
	status := ServiceStatus{Supported: true, Manager: "launchd", Unit: plistPath, Installed: true}
	_ = exec.Command("launchctl", "unload", plistPath).Run()
	if out, err := exec.Command("launchctl", "load", plistPath).CombinedOutput(); err != nil {
		status.Detail = strings.TrimSpace(string(out))
		return status, nil
	}
	status.Running = true
	return status, nil
}

// ---------------------------------------------------------------- windows

func installScheduledTask(install Install, exe string) (ServiceStatus, error) {
	status := ServiceStatus{Supported: true, Manager: "task scheduler", Unit: ServiceUnitName}
	cmd := exec.Command("schtasks", "/Create", "/F",
		"/SC", "ONLOGON",
		"/RL", "HIGHEST",
		"/TN", ServiceUnitName,
		"/TR", fmt.Sprintf(`"%s" serve --dir "%s"`, exe, install.Dir),
	)
	if out, err := cmd.CombinedOutput(); err != nil {
		return status, fmt.Errorf("schtasks: %s", strings.TrimSpace(string(out)))
	}
	status.Installed = true
	if out, err := exec.Command("schtasks", "/Run", "/TN", ServiceUnitName).CombinedOutput(); err != nil {
		status.Detail = strings.TrimSpace(string(out))
		return status, nil
	}
	status.Running = true
	return status, nil
}

// ServiceUnitPath is where this platform's service definition lives, or empty
// when nothing has been registered.
func ServiceUnitPath() string {
	switch runtime.GOOS {
	case "linux":
		if fileExists("/etc/systemd/system/" + ServiceUnitName + ".service") {
			return "/etc/systemd/system/" + ServiceUnitName + ".service"
		}
		if home, err := os.UserHomeDir(); err == nil {
			user := filepath.Join(home, ".config", "systemd", "user", ServiceUnitName+".service")
			if fileExists(user) {
				return user
			}
		}
	case "darwin":
		if home, err := os.UserHomeDir(); err == nil {
			plist := filepath.Join(home, "Library", "LaunchAgents",
				"dev.localdrive."+ServiceUnitName+".plist")
			if fileExists(plist) {
				return plist
			}
		}
	case "windows":
		out, err := exec.Command("schtasks", "/Query", "/TN", ServiceUnitName).CombinedOutput()
		if err == nil && len(out) > 0 {
			return ServiceUnitName
		}
	}
	return ""
}

// ServiceManaged reports whether something other than a terminal window is
// keeping this server up.
func ServiceManaged() bool { return ServiceUnitPath() != "" }

// ControlService starts, stops or restarts through the service manager.
//
// Update calls this after swapping the binary. Without it the new file is on
// disk and the old one is still the process that is running, and the only way
// out is knowing to run systemctl by hand.
func ControlService(action string) error {
	switch runtime.GOOS {
	case "linux":
		args := []string{}
		if !strings.HasPrefix(ServiceUnitPath(), "/etc/") {
			args = append(args, "--user")
		}
		args = append(args, action, ServiceUnitName+".service")
		out, err := exec.Command("systemctl", args...).CombinedOutput()
		if err != nil {
			return fmt.Errorf("systemctl %s: %s", action, strings.TrimSpace(string(out)))
		}
		return nil

	case "darwin":
		plist := ServiceUnitPath()
		verb := map[string]string{"start": "load", "stop": "unload", "restart": "kickstart"}[action]
		if verb == "kickstart" {
			_ = exec.Command("launchctl", "unload", plist).Run()
			verb = "load"
		}
		out, err := exec.Command("launchctl", verb, plist).CombinedOutput()
		if err != nil {
			return fmt.Errorf("launchctl %s: %s", verb, strings.TrimSpace(string(out)))
		}
		return nil

	case "windows":
		verb := "/Run"
		if action == "stop" {
			verb = "/End"
		}
		if action == "restart" {
			_ = exec.Command("schtasks", "/End", "/TN", ServiceUnitName).Run()
		}
		out, err := exec.Command("schtasks", verb, "/TN", ServiceUnitName).CombinedOutput()
		if err != nil {
			return fmt.Errorf("schtasks %s: %s", verb, strings.TrimSpace(string(out)))
		}
		return nil
	}
	return fmt.Errorf("no service manager is known for %s", runtime.GOOS)
}

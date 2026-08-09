package runner

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// DockerState is what a check of the host found.
type DockerState int

// The states worth telling apart, because the fix differs for each.
const (
	DockerReady DockerState = iota
	DockerNotInstalled
	DockerComposeMissing
	DockerNotRunning
)

// CheckDocker reports what is actually wrong, rather than one blanket error.
//
// The failure people hit by far the most often is the last one: Docker Desktop
// is installed and the command line tool works, but the engine itself lives
// inside a virtual machine that only starts when the Docker Desktop
// application is open. The command line then reports that it cannot reach the
// daemon, which reads like a broken install and is not one.
func CheckDocker() (DockerState, error) {
	if _, err := exec.LookPath("docker"); err != nil {
		return DockerNotInstalled, errors.New("Docker is not installed")
	}
	if out, err := exec.Command("docker", "compose", "version").CombinedOutput(); err != nil {
		_ = out
		return DockerComposeMissing, errors.New("Docker Compose is not available")
	}
	if err := exec.Command("docker", "info").Run(); err != nil {
		return DockerNotRunning, errors.New("the Docker engine is not running")
	}
	return DockerReady, nil
}

// ExplainDocker turns a state into the sentences someone can act on.
func ExplainDocker(state DockerState) []string {
	switch state {
	case DockerNotInstalled:
		return []string{
			"Docker is not installed on this machine.",
			"Install Docker Desktop from https://docs.docker.com/get-docker/",
			"then run this again.",
		}
	case DockerComposeMissing:
		return []string{
			"Docker is installed but Docker Compose is not.",
			"Updating Docker Desktop to a current version includes it.",
		}
	case DockerNotRunning:
		lines := []string{
			"Docker is installed, but its engine is not running.",
			"",
		}
		switch runtime.GOOS {
		case "windows":
			lines = append(lines,
				"On Windows the engine runs inside Docker Desktop. The command line",
				"tool is installed separately, which is why `docker` answers but",
				"`docker info` cannot reach anything.",
				"",
				"Open Docker Desktop and wait for the whale icon in the system tray",
				"to stop animating. To avoid this every time, turn on",
				"Settings, General, Start Docker Desktop when you sign in.",
			)
		case "darwin":
			lines = append(lines,
				"On macOS the engine runs inside Docker Desktop. Open it from",
				"Applications and wait for the whale icon in the menu bar to settle.",
			)
		default:
			lines = append(lines,
				"Start it with:",
				"",
				"    sudo systemctl start docker",
				"",
				"To have it start at boot:",
				"",
				"    sudo systemctl enable docker",
			)
		}
		return lines
	default:
		return nil
	}
}

// StartDockerDesktop launches the desktop application, where there is one.
// It returns false when there is nothing to launch, so the caller can fall
// back to telling the person what to do by hand.
func StartDockerDesktop() bool {
	switch runtime.GOOS {
	case "windows":
		candidates := []string{
			filepath.Join(os.Getenv("ProgramFiles"), "Docker", "Docker", "Docker Desktop.exe"),
			filepath.Join(os.Getenv("ProgramW6432"), "Docker", "Docker", "Docker Desktop.exe"),
			filepath.Join(os.Getenv("LOCALAPPDATA"), "Docker", "Docker Desktop.exe"),
		}
		for _, path := range candidates {
			if path == "" {
				continue
			}
			if _, err := os.Stat(path); err != nil {
				continue
			}
			if err := exec.Command("cmd", "/c", "start", "", path).Start(); err == nil {
				return true
			}
		}
	case "darwin":
		if err := exec.Command("open", "-a", "Docker").Start(); err == nil {
			return true
		}
	case "linux":
		// a service, not an application, and starting it needs a password the
		// tool should not be asking for
		return false
	}
	return false
}

// WaitForDocker polls until the engine answers, or gives up.
//
// Docker Desktop takes a while to bring its virtual machine up, and a person
// watching a blank terminal has no way to know whether anything is happening,
// so this says so while it waits.
func WaitForDocker(timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	frames := []string{".  ", ".. ", "..."}
	frame := 0

	for time.Now().Before(deadline) {
		if err := exec.Command("docker", "info").Run(); err == nil {
			fmt.Print("\r                                              \r")
			return true
		}
		fmt.Printf("\r    Waiting for the Docker engine %s", frames[frame%len(frames)])
		frame++
		time.Sleep(2 * time.Second)
	}
	fmt.Println()
	return false
}

// EnsureDocker checks, explains, and where it can, fixes.
// It returns whether the engine is usable by the time it is done.
func EnsureDocker(interactive bool) bool {
	state, _ := CheckDocker()
	if state == DockerReady {
		return true
	}

	for _, line := range ExplainDocker(state) {
		if line == "" {
			fmt.Println()
			continue
		}
		fmt.Println("    " + line)
	}

	if state != DockerNotRunning || !interactive {
		return false
	}

	fmt.Println()
	if !StartDockerDesktop() {
		return false
	}
	fmt.Println("    Starting Docker Desktop for you. This takes a minute the first time.")
	if !WaitForDocker(3 * time.Minute) {
		fmt.Println("    Docker did not finish starting. Open it yourself, then run this again.")
		return false
	}
	setupOk("The Docker engine is running")
	return true
}

// dockerHint is the one line other commands print when they cannot reach it.
func dockerHint() string {
	switch runtime.GOOS {
	case "windows", "darwin":
		return "open Docker Desktop and wait for it to finish starting"
	default:
		return "start it with: sudo systemctl start docker"
	}
}

var _ = strings.TrimSpace

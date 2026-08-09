package runner

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/updater"
)

// RunUpdate checks for a newer release and, unless asked only to look,
// installs it.
//
// Order: check, back up, download, verify, stop, swap, start, confirm it
// answers. Everything before the stop runs while the server is still serving,
// so a failed download or a bad checksum costs no downtime. Only the swap
// needs it stopped.
func RunUpdate(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}

	checkOnly := hasFlag(args, "check")
	skipBackup := hasFlag(args, "no-backup")

	setupHeader()

	// under Docker the binary on disk is not what runs. The image is the unit
	// of update, and replacing the file would change nothing while looking
	// like it had worked
	if install.HasCompose() && !checkOnly {
		fmt.Println("  This install runs under Docker, so the image is what updates.")
		fmt.Println()
		fmt.Println("      cd", install.Dir)
		fmt.Println("      docker compose pull")
		fmt.Println("      docker compose up -d")
		fmt.Println()
		fmt.Println("  Your database and library are untouched by that.")
		fmt.Println()
		return 0
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()

	fmt.Printf("  Currently running %s\n", Version)
	fmt.Println("  Checking for a newer release")

	release, err := updater.Check(ctx, Version)
	if errors.Is(err, updater.ErrNoUpdate) {
		fmt.Println()
		fmt.Println("  Already on the newest release. Nothing to do.")
		fmt.Println()
		return 0
	}
	if err != nil {
		return fail(err)
	}

	fmt.Println()
	fmt.Printf("  %s is available\n", release.Version)
	fmt.Printf("    %s, %s\n", release.AssetName, humanSize(release.Size))
	if release.Notes != "" {
		fmt.Println()
		for _, line := range firstLines(release.Notes, 8) {
			fmt.Printf("    %s\n", line)
		}
	}
	fmt.Println()
	fmt.Printf("    Full notes: %s\n", release.URL)
	fmt.Println()

	if checkOnly {
		fmt.Println("  Install it with: localdrive update")
		fmt.Println()
		return 0
	}

	// the binary is the only thing being replaced, but a backup before any
	// version change is cheap and is the one moment someone will wish they had
	if !skipBackup {
		fmt.Println("  Backing up the database and library first")
		if code := RunBackup(args); code != 0 {
			return failf("the backup failed, so the update stopped. " +
				"run again with --no-backup to update anyway")
		}
	}

	fmt.Println("  Downloading and verifying")
	path, err := updater.Apply(ctx, release)
	if err != nil {
		return fail(err)
	}
	fmt.Printf("    Installed to %s\n", path)
	fmt.Printf("    Previous version kept at %s.old\n", path)

	// the swap is done; from here the only thing left is turning it over
	fmt.Println()
	fmt.Println("  Restarting")

	wasRunning, _ := probeHealth(install.Port())
	if !wasRunning {
		fmt.Println("    The server was not running, so nothing to restart.")
		fmt.Println()
		fmt.Printf("  Updated to %s. Start it with: localdrive start\n", release.Version)
		fmt.Println()
		return 0
	}

	if code := RunRestart(args); code != 0 {
		return failf("the new binary is in place but the server did not restart. "+
			"roll back with: localdrive update --rollback\n"+
			"  the previous binary is at %s.old", path)
	}

	// a release that installs but will not serve is worse than one that fails
	// to install, so check rather than assume
	if err := waitHealthy(install, 45*time.Second); err != nil {
		fmt.Println()
		fmt.Println("  The new version is not answering. Rolling back.")
		if rollbackErr := updater.Rollback(); rollbackErr != nil {
			return failf("rollback failed: %v\n"+
				"  the previous binary is at %s.old, put it back by hand", rollbackErr, path)
		}
		RunRestart(args)
		return failf("rolled back to the previous version, which is running again")
	}

	fmt.Println()
	fmt.Printf("  Updated to %s and answering.\n", release.Version)
	fmt.Println()
	return 0
}

// RunRollback puts the previous binary back without downloading anything, for
// a release that installs and starts but behaves badly.
func RunRollback(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}

	setupHeader()
	fmt.Println("  Putting the previous binary back")

	if err := updater.Rollback(); err != nil {
		return fail(err)
	}
	if running, _ := probeHealth(install.Port()); running {
		RunRestart(args)
	}

	fmt.Println()
	fmt.Println("  Rolled back. Check it with: localdrive status")
	fmt.Println()
	return 0
}

func waitHealthy(install Install, within time.Duration) error {
	deadline := time.Now().Add(within)
	for time.Now().Before(deadline) {
		if ok, _ := probeHealth(install.Port()); ok {
			return nil
		}
		time.Sleep(2 * time.Second)
	}
	return errors.New("the server did not become healthy in time")
}

func hasFlag(args []string, name string) bool {
	for _, arg := range args {
		if strings.TrimLeft(arg, "-") == name {
			return true
		}
	}
	return false
}

func humanSize(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	value, suffix := float64(bytes)/unit, "KB"
	for _, next := range []string{"MB", "GB"} {
		if value < unit {
			break
		}
		value, suffix = value/unit, next
	}
	return fmt.Sprintf("%.1f %s", value, suffix)
}

func firstLines(text string, limit int) []string {
	lines := strings.Split(strings.ReplaceAll(text, "\r\n", "\n"), "\n")
	if len(lines) > limit {
		lines = append(lines[:limit], "...")
	}
	return lines
}

// Package updater checks for a newer release and replaces this binary with it.
//
// Downloading and verifying happen while the server keeps serving. Swapping
// the file needs a restart, because a process cannot become a different
// program without one, so there is a gap of a few seconds and the CLI says so.
//
// Nothing here touches the database or the library. Only the executable is
// replaced, and the previous one is kept next to it so a bad release can be
// undone without a download.
package updater

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

// Repo is where releases are published. Kept here rather than in config
// because a self-update that could be pointed at an arbitrary host by an
// environment variable is a way to install someone else's binary.
const Repo = "MultiX0/LocalDrive"

const apiBase = "https://api.github.com/repos/" + Repo

// ErrNoUpdate means the newest release is the one already running.
var ErrNoUpdate = errors.New("already on the newest release")

// ErrNotSupported means this build cannot replace itself, which is the case
// inside a container: the image is the unit of update there, not the file.
var ErrNotSupported = errors.New("this install updates by pulling a new image")

// Release is a published version and the file for this platform.
type Release struct {
	Version string
	Notes   string
	URL     string
	// AssetName is the file this platform needs, matching the release workflow
	AssetName string
	AssetURL  string
	Size      int64
	// ChecksumsURL points at SHA256SUMS, which every release carries
	ChecksumsURL string
}

// AssetName is the release file for the platform this binary was built for.
// It has to match .github/workflows/release.yml exactly.
func AssetName() string {
	switch {
	case runtime.GOOS == "windows":
		return "server.exe"
	case runtime.GOOS == "linux" && runtime.GOARCH == "arm64":
		return "server-arm64"
	case runtime.GOOS == "linux":
		return "server"
	default:
		return ""
	}
}

// Check asks for the newest stable release and reports whether it is newer
// than what is running.
//
// Prereleases are ignored. Someone who wants one can download it by hand;
// having an update command pull them silently is how a person ends up running
// a release candidate on the machine holding their photographs.
func Check(ctx context.Context, current string) (*Release, error) {
	asset := AssetName()
	if asset == "" {
		return nil, fmt.Errorf("no published build for %s/%s", runtime.GOOS, runtime.GOARCH)
	}

	var payload []struct {
		TagName    string `json:"tag_name"`
		Body       string `json:"body"`
		HTMLURL    string `json:"html_url"`
		Draft      bool   `json:"draft"`
		Prerelease bool   `json:"prerelease"`
		Assets     []struct {
			Name string `json:"name"`
			URL  string `json:"browser_download_url"`
			Size int64  `json:"size"`
		} `json:"assets"`
	}

	if err := getJSON(ctx, apiBase+"/releases?per_page=10", &payload); err != nil {
		return nil, err
	}

	for _, entry := range payload {
		if entry.Draft || entry.Prerelease {
			continue
		}

		release := &Release{
			Version: strings.TrimPrefix(entry.TagName, "v"),
			Notes:   strings.TrimSpace(entry.Body),
			URL:     entry.HTMLURL,
		}
		for _, item := range entry.Assets {
			switch item.Name {
			case asset:
				release.AssetName = item.Name
				release.AssetURL = item.URL
				release.Size = item.Size
			case "SHA256SUMS":
				release.ChecksumsURL = item.URL
			}
		}

		if release.AssetURL == "" {
			return nil, fmt.Errorf("release %s has no %s", release.Version, asset)
		}
		if !newer(release.Version, current) {
			return nil, ErrNoUpdate
		}
		return release, nil
	}

	return nil, ErrNoUpdate
}

// Apply downloads the release, checks it against the published hash, and puts
// it in place of the running binary.
//
// The old binary is kept as <name>.old. Windows needs this: a running
// executable cannot be deleted or overwritten, but it can be renamed, which
// frees the name for the new one.
func Apply(ctx context.Context, release *Release) (installedAt string, err error) {
	self, err := os.Executable()
	if err != nil {
		return "", err
	}
	if self, err = filepath.EvalSymlinks(self); err != nil {
		return "", err
	}

	// written beside the target, never in a temp directory: a rename across
	// filesystems is a copy, and a half-copied binary is a broken server
	staged := self + ".new"
	backup := self + ".old"

	if err := download(ctx, release, staged); err != nil {
		os.Remove(staged)
		return "", err
	}

	// the running file is moved aside rather than deleted, so a failure past
	// this point can put it straight back
	os.Remove(backup)
	if err := os.Rename(self, backup); err != nil {
		os.Remove(staged)
		return "", fmt.Errorf("could not move the current binary aside: %w", err)
	}

	if err := os.Rename(staged, self); err != nil {
		// put it back exactly as it was
		if restoreErr := os.Rename(backup, self); restoreErr != nil {
			return "", fmt.Errorf(
				"the update failed and the old binary could not be restored. "+
					"it is at %s, move it back to %s: %w", backup, self, err)
		}
		os.Remove(staged)
		return "", fmt.Errorf("could not put the new binary in place: %w", err)
	}

	if runtime.GOOS != "windows" {
		// a rename does not carry the mode across on every filesystem
		_ = os.Chmod(self, 0o755)
	}
	return self, nil
}

// Rollback puts the previous binary back, for a release that starts but
// misbehaves. Downloading nothing, so it works with no network.
func Rollback() error {
	self, err := os.Executable()
	if err != nil {
		return err
	}
	if self, err = filepath.EvalSymlinks(self); err != nil {
		return err
	}

	backup := self + ".old"
	if _, err := os.Stat(backup); err != nil {
		return fmt.Errorf("there is no previous binary at %s", backup)
	}

	current := self + ".new"
	os.Remove(current)
	if err := os.Rename(self, current); err != nil {
		return err
	}
	if err := os.Rename(backup, self); err != nil {
		_ = os.Rename(current, self)
		return err
	}
	os.Remove(current)
	return nil
}

func download(ctx context.Context, release *Release, into string) error {
	want, err := publishedHash(ctx, release)
	if err != nil {
		return err
	}

	response, err := get(ctx, release.AssetURL)
	if err != nil {
		return err
	}
	defer response.Body.Close()

	file, err := os.OpenFile(into, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o755)
	if err != nil {
		return err
	}

	digest := sha256.New()
	// hashed as it is written, so the bytes are never read twice and a large
	// binary never has to be held in memory
	if _, err := io.Copy(io.MultiWriter(file, digest), response.Body); err != nil {
		file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}

	got := hex.EncodeToString(digest.Sum(nil))
	if !strings.EqualFold(got, want) {
		return fmt.Errorf(
			"the downloaded file does not match the published checksum.\n"+
				"  expected %s\n  got      %s\n"+
				"nothing has been changed", want, got)
	}
	return nil
}

// publishedHash reads SHA256SUMS and finds the line for this platform's file.
func publishedHash(ctx context.Context, release *Release) (string, error) {
	if release.ChecksumsURL == "" {
		return "", errors.New("this release has no SHA256SUMS, so the download cannot be verified")
	}

	response, err := get(ctx, release.ChecksumsURL)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()

	scanner := bufio.NewScanner(response.Body)
	for scanner.Scan() {
		// "<hash>  <filename>", the sha256sum format
		fields := strings.Fields(scanner.Text())
		if len(fields) != 2 {
			continue
		}
		if strings.TrimPrefix(fields[1], "*") == release.AssetName {
			return fields[0], nil
		}
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	return "", fmt.Errorf("SHA256SUMS has no entry for %s", release.AssetName)
}

func get(ctx context.Context, url string) (*http.Response, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("User-Agent", "localdrive-updater")

	client := &http.Client{Timeout: 10 * time.Minute}
	response, err := client.Do(request)
	if err != nil {
		return nil, err
	}
	if response.StatusCode != http.StatusOK {
		response.Body.Close()
		return nil, fmt.Errorf("%s returned %s", url, response.Status)
	}
	return response, nil
}

func getJSON(ctx context.Context, url string, into any) error {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("User-Agent", "localdrive-updater")

	client := &http.Client{Timeout: 30 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return fmt.Errorf("could not reach GitHub: %w", err)
	}
	defer response.Body.Close()

	if response.StatusCode == http.StatusForbidden {
		return errors.New("GitHub is rate limiting this address, try again later")
	}
	if response.StatusCode != http.StatusOK {
		return fmt.Errorf("GitHub returned %s", response.Status)
	}
	return json.NewDecoder(response.Body).Decode(into)
}

// newer compares two dotted versions. An unparsable current version, which is
// what a build from source reports, counts as older than any release, so
// `update` on a source build offers the newest published one.
func newer(candidate, current string) bool {
	a, aOK := parse(candidate)
	b, bOK := parse(current)
	if !aOK {
		return false
	}
	if !bOK {
		return true
	}
	for i := range 3 {
		if a[i] != b[i] {
			return a[i] > b[i]
		}
	}
	return false
}

func parse(value string) ([3]int, bool) {
	var out [3]int
	// a prerelease suffix is not compared, only the numbers before it
	value = strings.TrimPrefix(value, "v")
	if index := strings.IndexAny(value, "-+"); index >= 0 {
		value = value[:index]
	}

	parts := strings.Split(value, ".")
	if len(parts) != 3 {
		return out, false
	}
	for i, part := range parts {
		number, err := strconv.Atoi(part)
		if err != nil {
			return out, false
		}
		out[i] = number
	}
	return out, true
}

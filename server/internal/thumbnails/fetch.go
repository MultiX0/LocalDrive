package thumbnails

import (
	"archive/zip"
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// The gaps between retries. One attempt meant a server that started while the
// network was settling gave up for the life of the process.
//
// Each gap is scattered, so servers that rebooted together do not all arrive
// in the same second.
var fetchBackoff = []time.Duration{
	15 * time.Second,
	1 * time.Minute,
	5 * time.Minute,
	20 * time.Minute,
	1 * time.Hour,
	3 * time.Hour,
}

// jitter spreads retries out.
func jitter(d time.Duration) time.Duration {
	spread := int64(d / 3)
	if spread <= 0 {
		return d
	}
	return d + time.Duration(rand.Int63n(spread))
}

// FetchWithRetry keeps trying until it has an ffmpeg that runs. A non-empty
// result has already been executed successfully.
func FetchWithRetry(ctx context.Context, log *slog.Logger, dir string) string {
	if log == nil {
		log = slog.Default()
	}
	for attempt := 0; ; attempt++ {
		if path := FetchFFmpeg(ctx, log, dir); path != "" {
			return path
		}
		if ctx.Err() != nil {
			return ""
		}
		if attempt >= len(fetchBackoff)-1 {
			log.Warn("giving up on fetching ffmpeg after repeated failures. "+
				"install it from your package manager for video previews",
				"attempts", attempt+1)
			return ""
		}
		wait := jitter(fetchBackoff[attempt])
		log.Info("could not fetch ffmpeg, trying again later",
			"attempt", attempt+1, "next_try_in", wait.String())
		select {
		case <-time.After(wait):
		case <-ctx.Done():
			return ""
		}
	}
}

// FetchEnv turns the automatic download off.
//
// It is on by default because a server with no video previews is a server that
// looks broken to the person running it, and "go and install ffmpeg" is not an
// answer for someone who was handed a binary. It is a single environment
// variable to turn off, because fetching an executable at runtime is a thing
// some operators will want to forbid outright, and they should not have to
// argue with the software about it.
const FetchEnv = "LOCALDRIVE_FETCH_FFMPEG"

// No pinned checksum, on purpose. The Linux builds sit at a rolling url whose
// contents change on every upstream release, with only an md5 beside them, so a
// pin would silently break previews the day upstream ships. The trust is in TLS
// and the host, the download is logged, and FetchEnv turns it off. Reasoned out
// in docs/contributing/security-review.mdx.

// where the builds come from, per platform. Static, so nothing here decides
// at runtime what to download from where.
var ffmpegBuilds = map[string]struct {
	url    string
	member string // the file inside the archive, matched by suffix
}{
	"windows/amd64": {
		url:    "https://github.com/GyanD/codexffmpeg/releases/download/7.1/ffmpeg-7.1-essentials_build.zip",
		member: "bin/ffmpeg.exe",
	},
	"linux/amd64": {
		url:    "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz",
		member: "ffmpeg",
	},
	"linux/arm64": {
		url:    "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz",
		member: "ffmpeg",
	},
}

// FetchFFmpeg downloads ffmpeg beside the server binary when it is missing.
//
// Returns the path it installed, or empty when it did not: turned off, no
// build published for this platform, or the download failed. None of those are
// errors worth stopping a server for. Video previews are a nicety, and a server
// that refuses to start because a CDN was unreachable would be far worse than
// one that shows a type badge on a video.
//
// macOS is deliberately absent. The published builds are unsigned, so Gatekeeper
// quarantines them and the first run fails in a way that looks like the app is
// broken rather than like a missing tool. Homebrew is the right answer there.
func FetchFFmpeg(ctx context.Context, log *slog.Logger, dir string) string {
	if log == nil {
		log = slog.Default()
	}
	if strings.EqualFold(strings.TrimSpace(os.Getenv(FetchEnv)), "false") {
		log.Info("not fetching ffmpeg because " + FetchEnv + " is false")
		return ""
	}

	build, ok := ffmpegBuilds[runtime.GOOS+"/"+runtime.GOARCH]
	if !ok {
		log.Info("no ffmpeg build published for this platform, install it by hand for video previews",
			"platform", runtime.GOOS+"/"+runtime.GOARCH)
		return ""
	}

	target := filepath.Join(dir, "ffmpeg")
	if runtime.GOOS == "windows" {
		target += ".exe"
	}

	// name the source and admit it is unverified, so the trust is visible
	log.Info("downloading ffmpeg for video previews, this happens once",
		"from", build.url,
		"checksum_pinned", false,
		"disable_with", FetchEnv+"=false")
	start := time.Now()

	if err := download(ctx, build.url, build.member, target); err != nil {
		log.Warn("could not fetch ffmpeg, videos will show a type badge instead of a preview",
			"error", err)
		return ""
	}

	// A file that arrived is not the same as a file that runs. Wrong
	// architecture, a truncated download and a corrupted archive all produce
	// something that looks installed and fails on the first video.
	if err := verify(ctx, target); err != nil {
		log.Warn("the downloaded ffmpeg does not run, ignoring it", "error", err)
		_ = os.Remove(target)
		return ""
	}

	log.Info("ffmpeg installed", "path", target, "took", time.Since(start).String())
	return target
}

func download(ctx context.Context, url, member, target string) error {
	// generous, because this is a large file on a connection nobody promised
	// anything about, and it only ever happens once
	ctx, cancel := context.WithTimeout(ctx, 10*time.Minute)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("the download answered %s", resp.Status)
	}

	// downloaded whole before being opened, because both archive formats need
	// to seek or stream from the start and a half written tool is worse than
	// none at all
	staged, err := os.CreateTemp(filepath.Dir(target), "ffmpeg-download-*")
	if err != nil {
		return err
	}
	stagedPath := staged.Name()
	defer os.Remove(stagedPath)

	if _, err := io.Copy(staged, resp.Body); err != nil {
		staged.Close()
		return err
	}
	if err := staged.Close(); err != nil {
		return err
	}

	if strings.HasSuffix(url, ".zip") {
		return extractZip(stagedPath, member, target)
	}
	return extractTar(stagedPath, member, target)
}

func extractZip(archive, member, target string) error {
	r, err := zip.OpenReader(archive)
	if err != nil {
		return err
	}
	defer r.Close()

	for _, f := range r.File {
		if !strings.HasSuffix(filepath.ToSlash(f.Name), member) {
			continue
		}
		in, err := f.Open()
		if err != nil {
			return err
		}
		defer in.Close()
		return write(in, target)
	}
	return fmt.Errorf("%s was not in the archive", member)
}

// extractTar unpacks the published linux builds.
//
// They are xz, which the standard library cannot read, so this shells out to
// tar rather than pulling in a decompressor. tar is on every linux that can
// run this server.
func extractTar(archive, member, target string) error {
	return extractWithTar(archive, member, target)
}

func extractWithTar(archive, member, target string) error {
	dir, err := os.MkdirTemp(filepath.Dir(target), "ffmpeg-unpack-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(dir)

	cmd := exec.Command("tar", "-xf", archive, "-C", dir)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("tar: %w: %s", err, strings.TrimSpace(string(out)))
	}

	var found string
	err = filepath.WalkDir(dir, func(path string, entry os.DirEntry, err error) error {
		if err != nil || entry.IsDir() || found != "" {
			return nil
		}
		if filepath.Base(path) == member {
			found = path
		}
		return nil
	})
	if err != nil {
		return err
	}
	if found == "" {
		return fmt.Errorf("%s was not in the archive", member)
	}

	in, err := os.Open(found)
	if err != nil {
		return err
	}
	defer in.Close()
	return write(in, target)
}

func write(in io.Reader, target string) error {
	// 0o755 because the whole point is that it can be executed afterwards
	out, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o755)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func verify(ctx context.Context, path string) error {
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()

	out, err := exec.CommandContext(ctx, path, "-version").CombinedOutput()
	if err != nil {
		return fmt.Errorf("%w: %s", err, strings.TrimSpace(string(out)))
	}
	if !strings.Contains(strings.ToLower(string(out)), "ffmpeg version") {
		return errors.New("it did not identify itself as ffmpeg")
	}
	return nil
}

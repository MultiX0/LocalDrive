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

// fetchAttempts and the backoff between them.
//
// One try was not enough. A server that comes up while the network is still
// settling, or while the upstream host is having a bad minute, would give up
// for the lifetime of the process and every video uploaded afterwards would
// have no preview until somebody restarted it.
//
// The gaps grow, and each is scattered by up to a third of itself, so a
// hundred servers that all started when the power came back do not knock on
// the same door at the same second.
var fetchBackoff = []time.Duration{
	15 * time.Second,
	1 * time.Minute,
	5 * time.Minute,
	20 * time.Minute,
	1 * time.Hour,
	3 * time.Hour,
}

// jitter spreads retries out. Deterministic sources are not needed here, and
// crypto/rand would be a strange dependency for choosing a delay.
func jitter(d time.Duration) time.Duration {
	spread := int64(d / 3)
	if spread <= 0 {
		return d
	}
	return d + time.Duration(rand.Int63n(spread))
}

// FetchWithRetry keeps trying until it has an ffmpeg that runs, then stops.
//
// It returns "" only when it has given up or been cancelled, so a caller can
// treat a non-empty result as a tool it has already executed successfully.
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

// These downloads are not checked against a pinned checksum, and that is a
// deliberate choice rather than an oversight.
//
// A pin needs a versioned artifact to pin to. The Linux builds are published
// at a rolling "release" url whose contents change with every upstream
// release, and the only digest beside them is md5. Pinning a hash to a url
// that changes means video previews stop working, silently, on the day
// upstream ships anything, which trades a small risk for a certainty of
// breaking. The alternative sources checked have the same rolling shape.
//
// So the trust here is in the host and in TLS, the download is announced in
// the log when it happens, and an operator who will not accept that has
// FetchEnv to turn it off and install ffmpeg from their own distribution.
// Recorded in docs/contributing/security-review.mdx so it stays a decision
// somebody made rather than something nobody noticed.

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

	// say where it comes from and that it is not checksum verified, so this is
	// a visible trust decision rather than a silent one. LOCALDRIVE_FETCH_FFMPEG
	// turns it off.
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

// Package thumbnails generates one cached JPEG preview per file, dispatched
// by MIME type. Types with no generator get a type badge on the client
// instead, which is expected behavior and never an error.
package thumbnails

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	"image/jpeg"
	_ "image/png"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	_ "golang.org/x/image/bmp"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/tiff"
	_ "golang.org/x/image/webp"
)

// Output settings, one shape for every generated preview.
const (
	// 512 was soft on a high density screen, where a 210 point tile is 420
	// physical pixels and a grid of them is the first thing anyone looks at
	MaxEdge = 1024
	Quality = 88
	// a generator that has not produced anything by now is stuck; the file
	// simply keeps its type badge
	generatorTimeout = 45 * time.Second
)

// ErrUnsupported means this MIME type intentionally has no rendered preview.
var ErrUnsupported = errors.New("thumbnails: no preview for this type")

// Capabilities records what the host can actually do, probed once at startup.
type Capabilities struct {
	FFmpeg   bool
	PDFToPPM bool

	// The resolved paths, kept because knowing a tool exists is not the same
	// as being able to run it. Probe searched PATH and the directory beside the
	// binary, then every exec still asked for the bare name and searched PATH
	// again, so a server that logged "video thumbnails enabled" failed every
	// single job with "executable file not found in %PATH%".
	FFmpegPath   string
	PDFToPPMPath string
}

// Generator turns a source file into a preview JPEG.
type Generator struct {
	// guards caps, which a background fetch can fill in after startup
	mu      sync.RWMutex
	caps    Capabilities
	log     *slog.Logger
	tempDir string

	// onFFmpeg fires once, when a background fetch finally produces a working
	// ffmpeg. Anything uploaded before that moment was skipped, so somebody
	// has to go back for it.
	onFFmpeg func()
}

// OnFFmpegReady registers a callback for the moment video support appears.
//
// It fires only when ffmpeg arrives late, by download. When ffmpeg was already
// on PATH at startup there was never a gap, so there is nothing to go back
// for and nothing is called.
func (g *Generator) OnFFmpegReady(fn func()) {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.onFFmpeg = fn
}

// Caps reports what the generator can do right now.
func (g *Generator) Caps() Capabilities {
	g.mu.RLock()
	defer g.mu.RUnlock()
	return g.caps
}

// Probe looks for the optional external tools once and logs the result.
func Probe(log *slog.Logger, tempDir string) *Generator {
	if log == nil {
		log = slog.Default()
	}
	g := &Generator{log: log, tempDir: tempDir}
	if path := find("ffmpeg"); path != "" {
		g.caps.FFmpeg = true
		g.caps.FFmpegPath = path
		log.Info("video thumbnails enabled", "ffmpeg", path)
	} else if dir := installDir(tempDir); dir != "" {
		// Fetched in the background. Downloading a hundred megabytes before the
		// server will answer a request would turn a first run into a wait with
		// nothing on screen, and everything except video previews works
		// perfectly well without it.
		log.Info("ffmpeg is missing, fetching it in the background for video previews")
		go func() {
			if found := FetchWithRetry(context.Background(), log, dir); found != "" {
				g.mu.Lock()
				g.caps.FFmpeg = true
				g.caps.FFmpegPath = found
				arrived := g.onFFmpeg
				g.mu.Unlock()
				log.Info("video thumbnails enabled", "ffmpeg", found)
				// Every video uploaded while this was downloading was skipped,
				// and nothing would ever look at it again. Tell whoever asked
				// so those can be picked up.
				if arrived != nil {
					arrived()
				}
			}
		}()
	} else {
		// said as an instruction rather than a fact, because "not found" on its
		// own leaves someone with videos that have no preview and no idea that
		// it is fixable, or how
		log.Warn("ffmpeg not found, so videos will have no preview. " +
			"Install ffmpeg and put it on PATH, or drop ffmpeg.exe beside the " +
			"Local Drive binary, then restart")
	}
	if path := find("pdftoppm"); path != "" {
		g.caps.PDFToPPM = true
		g.caps.PDFToPPMPath = path
		log.Info("pdf thumbnails enabled", "pdftoppm", path)
	} else {
		log.Info("pdftoppm not found, so pdf files will show a type badge instead of a preview")
	}
	return g
}

// hasBytes reports whether a helper actually wrote something.
func hasBytes(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Size() > 0
}

// FindFFmpeg reports an ffmpeg that is already installed, or "" if there is
// none. Exported so setup can ask the same question the generator asks, using
// the same search order, rather than keeping a second copy of it.
func FindFFmpeg() string { return find("ffmpeg") }

// find locates a helper on PATH, then beside the server binary.
//
// A self hosted server is often a binary somebody dropped in a folder, not an
// install with a package manager behind it. Looking next to ourselves means
// ffmpeg.exe can simply be put there, which is a far easier instruction than
// editing the system PATH on Windows.
func find(name string) string {
	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	candidate := filepath.Join(filepath.Dir(exe), name)
	if runtime.GOOS == "windows" {
		candidate += ".exe"
	}
	if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
		return candidate
	}
	return ""
}

// installDir picks somewhere writable to put a fetched tool.
//
// Beside the binary first, so it is found again on the next start by the same
// lookup that finds a hand installed one, and travels with the folder if it is
// moved. A binary in Program Files or /usr/local/bin is not writable by the
// account running the server, so the data directory is the fallback.
func installDir(tempDir string) string {
	candidates := make([]string, 0, 2)
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Dir(exe))
	}
	if tempDir != "" {
		candidates = append(candidates, filepath.Dir(tempDir))
	}
	for _, dir := range candidates {
		probe, err := os.CreateTemp(dir, ".write-probe-*")
		if err != nil {
			continue
		}
		name := probe.Name()
		probe.Close()
		os.Remove(name)
		return dir
	}
	return ""
}

// Supports reports whether this MIME type has a working generator right now.
//
// Read under a lock because a fetched ffmpeg arrives after startup, so this
// answer can change while the server is running.
func (g *Generator) Supports(mimeType string) bool {
	g.mu.RLock()
	defer g.mu.RUnlock()
	switch kind(mimeType) {
	case kindImage:
		return true
	case kindVideo:
		return g.caps.FFmpeg
	case kindPDF:
		return g.caps.PDFToPPM
	default:
		return false
	}
}

type mediaKind int

const (
	kindOther mediaKind = iota
	kindImage
	kindVideo
	kindPDF
)

func kind(mimeType string) mediaKind {
	m := strings.ToLower(strings.TrimSpace(mimeType))
	switch {
	case m == "application/pdf":
		return kindPDF
	case strings.HasPrefix(m, "image/"):
		// svg is markup, not a raster the decoder can read
		if strings.Contains(m, "svg") {
			return kindOther
		}
		return kindImage
	case strings.HasPrefix(m, "video/"):
		return kindVideo
	default:
		return kindOther
	}
}

// Generate returns JPEG bytes for one source file, or ErrUnsupported.
func (g *Generator) Generate(ctx context.Context, sourcePath, mimeType string) ([]byte, error) {
	switch kind(mimeType) {
	case kindImage:
		return g.fromImage(sourcePath)
	case kindVideo:
		if !g.Caps().FFmpeg {
			return nil, ErrUnsupported
		}
		return g.fromVideo(ctx, sourcePath)
	case kindPDF:
		if !g.Caps().PDFToPPM {
			return nil, ErrUnsupported
		}
		return g.fromPDF(ctx, sourcePath)
	default:
		return nil, ErrUnsupported
	}
}

func (g *Generator) fromImage(path string) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	src, _, err := image.Decode(f)
	if err != nil {
		return nil, fmt.Errorf("thumbnails: decode: %w", err)
	}
	// the camera's own idea of which way is up, applied before anything is
	// scaled, so the thumbnail matches what every other viewer shows
	src = applyOrientation(src, readOrientation(path))
	return encode(resize(src))
}

func (g *Generator) fromVideo(ctx context.Context, path string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, generatorTimeout)
	defer cancel()
	out, err := g.tempFile("frame-*.jpg")
	if err != nil {
		return nil, err
	}
	defer os.Remove(out)

	// a fixed argument list, never a shell, so nothing here is injectable
	cmd := exec.CommandContext(ctx, g.Caps().FFmpegPath,
		"-hide_banner", "-loglevel", "error", "-y",
		"-ss", "00:00:03",
		"-i", path,
		"-frames:v", "1",
		"-vf", fmt.Sprintf("scale='min(%d,iw)':-2", MaxEdge),
		out,
	)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	runErr := cmd.Run()

	// A clip shorter than the seek point has no frame there, and ffmpeg says so
	// by exiting 0 and writing nothing at all. Judging success by the exit code
	// alone meant a short clip produced an empty file that the decoder then
	// rejected as "unknown format", which reads like a corrupt video rather
	// than a seek past the end. Ask whether a frame actually arrived.
	if runErr != nil || !hasBytes(out) {
		cmd = exec.CommandContext(ctx, g.Caps().FFmpegPath,
			"-hide_banner", "-loglevel", "error", "-y",
			"-i", path, "-frames:v", "1",
			"-vf", fmt.Sprintf("scale='min(%d,iw)':-2", MaxEdge), out)
		stderr.Reset()
		cmd.Stderr = &stderr
		if err := cmd.Run(); err != nil {
			return nil, fmt.Errorf("thumbnails: ffmpeg: %w: %s", err, strings.TrimSpace(stderr.String()))
		}
		if !hasBytes(out) {
			return nil, fmt.Errorf("thumbnails: ffmpeg produced no frame: %s",
				strings.TrimSpace(stderr.String()))
		}
	}
	return g.fromImage(out)
}

func (g *Generator) fromPDF(ctx context.Context, path string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, generatorTimeout)
	defer cancel()
	dir, err := os.MkdirTemp(g.tempDir, "pdf-*")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)

	prefix := filepath.Join(dir, "page")
	cmd := exec.CommandContext(ctx, g.Caps().PDFToPPMPath,
		"-jpeg", "-r", "72", "-f", "1", "-l", "1", "-singlefile",
		"-scale-to", fmt.Sprintf("%d", MaxEdge),
		path, prefix,
	)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("thumbnails: pdftoppm: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	matches, err := filepath.Glob(prefix + ".*")
	if err != nil || len(matches) == 0 {
		return nil, errors.New("thumbnails: pdftoppm produced no page")
	}
	return g.fromImage(matches[0])
}

func (g *Generator) tempFile(pattern string) (string, error) {
	f, err := os.CreateTemp(g.tempDir, pattern)
	if err != nil {
		return "", err
	}
	name := f.Name()
	f.Close()
	return name, nil
}

// resize scales an image down so its long edge is at most MaxEdge, never up.
func resize(src image.Image) image.Image {
	bounds := src.Bounds()
	w, h := bounds.Dx(), bounds.Dy()
	if w <= 0 || h <= 0 {
		return src
	}
	if w <= MaxEdge && h <= MaxEdge {
		return src
	}
	scale := float64(MaxEdge) / float64(w)
	if h > w {
		scale = float64(MaxEdge) / float64(h)
	}
	dstW := int(float64(w) * scale)
	dstH := int(float64(h) * scale)
	if dstW < 1 {
		dstW = 1
	}
	if dstH < 1 {
		dstH = 1
	}
	dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
	draw.CatmullRom.Scale(dst, dst.Bounds(), src, bounds, draw.Over, nil)
	return dst
}

func encode(img image.Image) ([]byte, error) {
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: Quality}); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

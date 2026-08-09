package thumbnails

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

// Probe finding a tool and Generate being able to run it are two different
// things, and they came apart: Probe searched PATH and the directory beside
// the binary, logged "video thumbnails enabled" with a full path, then every
// exec asked for the bare name and searched PATH again. Every video job failed
// with "executable file not found in %PATH%" on a server that had just said
// video thumbnails were on.
func TestProbeRecordsThePathItRunsWith(t *testing.T) {
	g := Probe(nil, t.TempDir())
	if g.caps.FFmpeg && g.caps.FFmpegPath == "" {
		t.Fatal("ffmpeg was found but no path was kept, so exec will search PATH again")
	}
	if g.caps.PDFToPPM && g.caps.PDFToPPMPath == "" {
		t.Fatal("pdftoppm was found but no path was kept")
	}
	if g.caps.FFmpegPath != "" && !filepath.IsAbs(g.caps.FFmpegPath) {
		t.Fatalf("the kept path must be absolute so exec never guesses: %q", g.caps.FFmpegPath)
	}
}

// The real thing, end to end, when a video and an ffmpeg are both available.
func TestGenerateMakesAVideoThumbnail(t *testing.T) {
	sample := os.Getenv("LD_TEST_VIDEO")
	if sample == "" {
		t.Skip("set LD_TEST_VIDEO to a video file to run this")
	}
	g := Probe(nil, t.TempDir())
	if !g.caps.FFmpeg {
		t.Skip("no ffmpeg on this machine")
	}
	if !g.Supports("video/mp4") {
		t.Fatal("ffmpeg is present but video/mp4 reports unsupported")
	}

	out, err := g.Generate(context.Background(), sample, "video/mp4")
	if err != nil {
		t.Fatalf("generating a video thumbnail failed: %v", err)
	}
	if len(out) == 0 {
		t.Fatal("the generator returned no bytes")
	}
	// a JPEG starts FF D8 FF, so this proves a real frame came back rather
	// than an empty file the encoder happened not to error on
	if len(out) < 3 || out[0] != 0xFF || out[1] != 0xD8 || out[2] != 0xFF {
		t.Fatalf("expected a JPEG, got % x", out[:min(8, len(out))])
	}
	t.Logf("video thumbnail generated: %d bytes", len(out))
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// The automatic fetch, end to end, in a directory with no ffmpeg in it.
//
// Skipped unless LD_TEST_FETCH is set, because it downloads roughly ninety
// megabytes and no test suite should do that without being asked.
func TestFetchFFmpegInstallsSomethingThatRuns(t *testing.T) {
	if os.Getenv("LD_TEST_FETCH") == "" {
		t.Skip("set LD_TEST_FETCH=1 to run the real download")
	}
	dir := t.TempDir()
	path := FetchFFmpeg(context.Background(), nil, dir)
	if path == "" {
		t.Fatal("nothing was installed")
	}
	if info, err := os.Stat(path); err != nil || info.Size() == 0 {
		t.Fatalf("the installed file is missing or empty: %v", err)
	}
	// FetchFFmpeg only returns a path after running it, so reaching here means
	// the binary identified itself as ffmpeg
	t.Logf("installed %s", path)
}

// Turning it off has to actually turn it off.
func TestFetchRespectsTheOffSwitch(t *testing.T) {
	t.Setenv(FetchEnv, "false")
	if path := FetchFFmpeg(context.Background(), nil, t.TempDir()); path != "" {
		t.Fatalf("it fetched anyway and installed %q", path)
	}
}

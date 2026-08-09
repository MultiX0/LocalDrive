package runner

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/thumbnails"
)

// setupFFmpeg gets video previews working before the server serves anything.
//
// Doing it here means the first upload already has previews, rather than
// whenever a background download happened to finish.
//
// Optional. A failure costs previews and nothing else, so it says so and
// carries on.
func setupFFmpeg() {
	setupStep("Video previews")

	if found := thumbnails.FindFFmpeg(); found != "" {
		setupOk("ffmpeg is already installed")
		return
	}
	if strings.EqualFold(strings.TrimSpace(os.Getenv(thumbnails.FetchEnv)), "false") {
		setupOk("skipped, because " + thumbnails.FetchEnv + " is false")
		return
	}

	dir := installDirForFFmpeg()
	if dir == "" {
		setupOk("skipped, nowhere writable to put it")
		return
	}

	fmt.Println("    Downloading ffmpeg so videos get a preview picture. Once,")
	fmt.Println("    about thirty megabytes. Nothing else needs it.")

	// setup is a conversation, not a log stream
	quiet := slog.New(slog.NewTextHandler(io.Discard, nil))
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	if path := thumbnails.FetchFFmpeg(ctx, quiet, dir); path != "" {
		setupOk("video previews are ready")
		return
	}

	setupOk("could not download ffmpeg, so videos show a type badge for now")
	fmt.Println("    The server keeps trying on its own, with longer gaps each")
	fmt.Println("    time, and goes back for anything uploaded meanwhile.")
}

// installDirForFFmpeg is beside this binary, where the generator looks after
// PATH.
func installDirForFFmpeg() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}
	return filepath.Dir(exe)
}

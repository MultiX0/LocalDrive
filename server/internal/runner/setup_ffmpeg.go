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

// setupFFmpeg gets video previews working before the server ever serves a
// request, and says out loud what it is doing.
//
// The alternative, which is what used to happen, is that the server starts,
// somebody uploads a video in the first minute, and it has no preview because
// the download was still in flight. That reads as a broken feature rather than
// as a gap that closes.
//
// Everything here is optional. A failure costs video previews and nothing
// else, so it reports and carries on rather than stopping a setup that has
// already written a working configuration.
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

	// The fetch logs at info level and setup is a conversation, not a log
	// stream, so its output goes nowhere and the result is reported here.
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

// installDirForFFmpeg is the directory beside this binary, which is where the
// generator looks after PATH.
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

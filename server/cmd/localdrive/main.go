// Command localdrive is the whole of Local Drive in one executable.
//
// It is the installer, the server, the drive helper, the network announcer,
// and the day to day controls, chosen by the first argument. One binary means
// one thing to download, one thing to update, and one version number.
//
// Running several modes out of one file does not weaken the privilege
// separation the design depends on: the boundary is the process and the
// container it runs in, not the file on disk. `mount-helper` still runs alone
// in its own container with only the capabilities that one job needs, and
// still talks to the server over a Unix socket with a shared secret.
package main

import (
	"os"

	"github.com/MultiX0/LocalDrive/server/internal/runner"
)

// version is stamped at build time with -ldflags.
var version = "dev"

func main() {
	runner.Version = version
	os.Exit(runner.Main(os.Args))
}

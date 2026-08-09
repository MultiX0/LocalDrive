package runner

import (
	"fmt"
	"os"
	"runtime"
	"sort"
	"strings"
)

// Version is stamped at build time with -ldflags. One binary, one version.
var Version = "dev"

// DefaultPort is the one port Local Drive serves on.
//
// Not 443, and not 80. A self-hosted server usually shares a machine with
// whatever else that machine already does, and 443 is the first thing anything
// else will want. 7443 reads as "443, but ours", is outside the range a distro
// hands out to system services, and does not collide with anything common.
const DefaultPort = 7443

// InternalPort is what the Go process listens on inside the Docker network,
// behind the proxy. Nothing outside the compose network ever reaches it.
const InternalPort = 8080

// Mode is one thing the binary can be told to do.
type Mode struct {
	Name    string
	Summary string
	Run     func(args []string) int

	// hidden modes are the ones a container calls, not a person
	Hidden bool
}

// Modes is the whole surface of the binary, in the order help prints them.
func Modes() []Mode {
	return []Mode{
		{
			Name:    "setup",
			Summary: "set up and start a server on this machine",
			Run:     RunSetup,
		},
		{
			Name:    "init",
			Summary: "write a working configuration without asking anything",
			Run:     RunInit,
		},
		{
			Name:    "serve",
			Summary: "run the server in the foreground, with no Docker",
			Run:     RunServer,
		},
		{
			Name:    "start",
			Summary: "start an already configured server",
			Run:     RunStart,
		},
		{
			Name:    "stop",
			Summary: "stop a running server",
			Run:     RunStop,
		},
		{
			Name:    "restart",
			Summary: "restart a running server",
			Run:     RunRestart,
		},
		{
			Name:    "status",
			Summary: "show whether the server is up, and where to reach it",
			Run:     RunStatus,
		},
		{
			Name:    "logs",
			Summary: "follow the server log",
			Run:     RunLogs,
		},
		{
			Name:    "reset-admin",
			Summary: "reset the admin password on an existing install",
			Run:     RunResetAdmin,
		},
		{
			Name:    "backup",
			Summary: "write a backup of the database and the library",
			Run:     RunBackup,
		},
		{
			Name:    "update",
			Summary: "check for a newer release and install it",
			Run:     RunUpdate,
		},
		{
			Name:    "rollback",
			Summary: "go back to the previous version",
			Run:     RunRollback,
		},
		{
			Name:    "version",
			Summary: "print the version",
			Run:     RunVersion,
		},
		// the three a container calls
		{Name: "mount-helper", Summary: "run the drive helper", Run: RunMountHelper, Hidden: true},
		{Name: "lan-discovery", Summary: "run the network announcer", Run: RunDiscovery, Hidden: true},
		{Name: "healthcheck", Summary: "probe a running server", Run: RunHealthcheck, Hidden: true},
	}
}

// Main dispatches to a mode. With no arguments it runs setup, because someone
// who just downloaded this and double-clicked it wants to set a server up.
func Main(argv []string) int {
	name := "setup"
	var rest []string
	if len(argv) > 1 {
		name = strings.TrimLeft(argv[1], "-")
		rest = argv[2:]
	}

	switch name {
	case "help", "h", "?":
		PrintUsage()
		return 0
	}

	for _, mode := range Modes() {
		if mode.Name == name {
			return mode.Run(rest)
		}
	}

	fmt.Fprintf(os.Stderr, "localdrive: no such command %q\n\n", name)
	PrintUsage()
	return 2
}

// RunVersion prints what this binary is.
func RunVersion(args []string) int {
	fmt.Printf("localdrive %s (%s/%s, %s)\n",
		Version, runtime.GOOS, runtime.GOARCH, runtime.Version())
	return 0
}

// PrintUsage lists the commands a person would actually type.
func PrintUsage() {
	modes := Modes()
	sort.SliceStable(modes, func(i, j int) bool { return false })

	fmt.Println()
	fmt.Println("  Local Drive")
	fmt.Println("  Your own file server, on your own hardware.")
	fmt.Println()
	fmt.Println("  Usage: localdrive <command>")
	fmt.Println()
	for _, mode := range modes {
		if mode.Hidden {
			continue
		}
		fmt.Printf("    %-14s %s\n", mode.Name, mode.Summary)
	}
	fmt.Println()
	fmt.Println("  Run it with no command at all to set a server up.")
	fmt.Println()
}

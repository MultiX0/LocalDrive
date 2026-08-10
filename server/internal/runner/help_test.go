package runner

import "testing"

// Asking what a command does must never be the same as doing it.
//
// Main stripped dashes off the command name only, so everything after it was
// handed to the mode, which ignored it and ran. `reset-admin --help` rewrote
// the admin password and printed it, `stop --help` stopped a running server,
// and `backup --help` wrote a backup. This was found by typing it.
func TestHelpFlagNeverRunsTheCommand(t *testing.T) {
	for _, args := range [][]string{
		{"--help"},
		{"-h"},
		{"--dir", "/somewhere", "--help"},
	} {
		if !wantsHelp(args) {
			t.Errorf("wantsHelp(%q) = false, so the command would have run", args)
		}
	}
}

// A positional argument that happens to read like a word is not a request for
// help. `backup help` writes a backup into a directory called help.
func TestOnlyTheFlagsCountAsAskingForHelp(t *testing.T) {
	for _, args := range [][]string{
		{"help"},
		{"/backups/help"},
		{"--dir", "/srv/help"},
		{},
	} {
		if wantsHelp(args) {
			t.Errorf("wantsHelp(%q) = true, so a real argument was mistaken for a flag", args)
		}
	}
}

// Every visible command has to have something to print, or the help flag lands
// on a blank screen.
func TestEveryCommandCanDescribeItself(t *testing.T) {
	for _, mode := range Modes() {
		if mode.Name == "" {
			t.Error("a mode has no name")
		}
		if mode.Summary == "" {
			t.Errorf("%s has no summary, so its help would be empty", mode.Name)
		}
		if mode.Run == nil {
			t.Errorf("%s has nothing to run", mode.Name)
		}
	}
}

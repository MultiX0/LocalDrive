package pathsafe

import (
	"path/filepath"
	"runtime"
	"testing"
)

func TestValidateName(t *testing.T) {
	cases := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{"plain", "report.pdf", false},
		{"spaces", "my holiday photos", false},
		{"unicode", "صور العائلة", false},
		{"dot prefix", ".hidden", false},
		{"empty", "", true},
		{"whitespace only", "   ", true},
		{"dot", ".", true},
		{"dotdot", "..", true},
		{"forward slash", "a/b", true},
		{"back slash", `a\b`, true},
		{"null byte", "a\x00b", true},
		{"newline", "a\nb", true},
		{"tab", "a\tb", true},
		{"windows device", "CON", true},
		{"windows device with extension", "nul.txt", true},
		{"too long", string(make([]byte, MaxNameLength+1)), true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateName(tc.input)
			if tc.wantErr && err == nil {
				t.Fatalf("expected %q to be rejected", tc.input)
			}
			if !tc.wantErr && err != nil {
				t.Fatalf("expected %q to be accepted, got %v", tc.input, err)
			}
		})
	}
}

func TestJoinRefusesTraversal(t *testing.T) {
	root := t.TempDir()
	cases := []struct {
		name    string
		parts   []string
		wantErr bool
	}{
		{"simple", []string{"objects", "aa", "bb"}, false},
		{"nested", []string{"a", "b", "c", "d.txt"}, false},
		{"single dotdot", []string{".."}, true},
		{"escaping suffix", []string{"objects", "..", "..", "etc", "passwd"}, true},
		{"embedded traversal", []string{"../../../etc/passwd"}, true},
		{"absolute unix", []string{"/etc/passwd"}, runtime.GOOS != "windows"},
		{"dot segments that stay inside", []string{"a", "..", "b"}, false},
		{"null byte", []string{"a\x00b"}, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := Join(root, tc.parts...)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("expected %v to be refused, got %q", tc.parts, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("expected %v to be accepted, got %v", tc.parts, err)
			}
			if !Within(root, got) {
				t.Fatalf("%q escaped %q", got, root)
			}
		})
	}
}

func TestWithin(t *testing.T) {
	root := t.TempDir()
	cases := []struct {
		child string
		want  bool
	}{
		{root, true},
		{filepath.Join(root, "a"), true},
		{filepath.Join(root, "a", "b"), true},
		{filepath.Dir(root), false},
		{filepath.Join(filepath.Dir(root), "sibling"), false},
	}
	for _, tc := range cases {
		if got := Within(root, tc.child); got != tc.want {
			t.Fatalf("Within(%q, %q) = %v, want %v", root, tc.child, got, tc.want)
		}
	}
}

func TestCleanNameAlwaysProducesSomething(t *testing.T) {
	cases := map[string]string{
		"normal.txt":   "normal.txt",
		"a/b":          "a_b",
		"":             "unnamed",
		"...":          "unnamed",
		"with\x00null": "with_null",
	}
	for input, want := range cases {
		if got := CleanName(input); got != want {
			t.Fatalf("CleanName(%q) = %q, want %q", input, got, want)
		}
	}
}

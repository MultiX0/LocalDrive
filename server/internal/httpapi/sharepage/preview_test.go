package sharepage

import "testing"

// Only what a browser plays on its own. Offering a viewer that renders nothing
// is worse than offering a download and being honest about it.
func TestOnlyPicturesVideoAndAudioPreview(t *testing.T) {
	cases := map[string]string{
		"image/jpeg":      "image",
		"image/png":       "image",
		"IMAGE/WEBP":      "image",
		"video/mp4":       "video",
		"video/quicktime": "video",
		"audio/mpeg":      "audio",
		"audio/flac":      "audio",

		// nothing else, however tempting
		"application/pdf": "",
		"text/plain":      "",
		"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "",
		"application/zip": "",
		"":                "",

		// svg is markup the browser executes, from a file somebody else
		// uploaded, served from this server's own origin
		"image/svg+xml": "",
	}

	for mime, want := range cases {
		if got := PreviewKind(mime); got != want {
			t.Errorf("PreviewKind(%q) = %q, want %q", mime, got, want)
		}
	}
}

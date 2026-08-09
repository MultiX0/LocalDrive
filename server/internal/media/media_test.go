package media

import (
	"bytes"
	"encoding/binary"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"os"
	"path/filepath"
	"testing"
)

func writeTemp(t *testing.T, name string, data []byte) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), name)
	if err := os.WriteFile(path, data, 0o600); err != nil {
		t.Fatalf("writing %s: %v", name, err)
	}
	return path
}

func solidPNG(t *testing.T, w, h int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for x := range w {
		for y := range h {
			img.Set(x, y, color.RGBA{R: 10, G: 20, B: 30, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encoding png: %v", err)
	}
	return buf.Bytes()
}

// jpegWithExif builds a JPEG carrying one APP1 segment with the tags given.
// Written by hand rather than checked in as a binary, so what is being parsed
// is visible in the test rather than opaque.
func jpegWithExif(t *testing.T, w, h int, tags map[uint16]string, orientation uint16) []byte {
	t.Helper()

	img := image.NewRGBA(image.Rect(0, 0, w, h))
	var body bytes.Buffer
	if err := jpeg.Encode(&body, img, nil); err != nil {
		t.Fatalf("encoding jpeg: %v", err)
	}
	raw := body.Bytes()

	// the TIFF block: header, one IFD, then the string values it points at
	var tiff bytes.Buffer
	tiff.WriteString("MM")                            // big endian
	binary.Write(&tiff, binary.BigEndian, uint16(42)) // magic
	binary.Write(&tiff, binary.BigEndian, uint32(8))  // first IFD at 8
	entries := len(tags)
	if orientation != 0 {
		entries++
	}
	binary.Write(&tiff, binary.BigEndian, uint16(entries))

	// values live after the directory and its next-offset word
	valueBase := uint32(8 + 2 + entries*12 + 4)
	var values bytes.Buffer

	if orientation != 0 {
		// both have to be written as uint16 explicitly: binary.Write refuses an
		// untyped constant, and it refuses it by returning an error rather than
		// by failing to compile, so an unconverted one writes nothing at all
		binary.Write(&tiff, binary.BigEndian, uint16(tagOrientation))
		binary.Write(&tiff, binary.BigEndian, uint16(typeShort))
		binary.Write(&tiff, binary.BigEndian, uint32(1))
		binary.Write(&tiff, binary.BigEndian, orientation)
		tiff.Write([]byte{0, 0}) // shorts are left-aligned in the four bytes
	}

	for tag, value := range tags {
		payload := append([]byte(value), 0)
		binary.Write(&tiff, binary.BigEndian, tag)
		binary.Write(&tiff, binary.BigEndian, uint16(typeASCII))
		binary.Write(&tiff, binary.BigEndian, uint32(len(payload)))
		binary.Write(&tiff, binary.BigEndian, valueBase+uint32(values.Len()))
		values.Write(payload)
	}

	binary.Write(&tiff, binary.BigEndian, uint32(0)) // no next IFD
	tiff.Write(values.Bytes())

	var app1 bytes.Buffer
	app1.WriteString("Exif")
	app1.Write([]byte{0, 0})
	app1.Write(tiff.Bytes())

	var out bytes.Buffer
	out.Write(raw[:2]) // SOI
	out.Write([]byte{0xFF, 0xE1})
	binary.Write(&out, binary.BigEndian, uint16(app1.Len()+2))
	out.Write(app1.Bytes())
	out.Write(raw[2:])
	return out.Bytes()
}

func TestProbeReadsDimensions(t *testing.T) {
	path := writeTemp(t, "shot.png", solidPNG(t, 640, 360))

	info, err := Probe(path)
	if err != nil {
		t.Fatalf("probing: %v", err)
	}
	if info.Width != 640 || info.Height != 360 {
		t.Fatalf("got %dx%d, want 640x360", info.Width, info.Height)
	}
	// a PNG carries no capture time, and inventing one would put it in the
	// wrong place in a gallery sorted by when things were taken
	if info.TakenAt != 0 {
		t.Fatalf("got a capture time of %d for a file that has none", info.TakenAt)
	}
}

func TestProbeReadsCaptureTime(t *testing.T) {
	data := jpegWithExif(t, 100, 50, map[uint16]string{
		tagDateTimeOriginal: "2019:07:14 18:32:05",
	}, 0)
	path := writeTemp(t, "photo.jpg", data)

	info, err := Probe(path)
	if err != nil {
		t.Fatalf("probing: %v", err)
	}
	// 2019-07-14T18:32:05Z
	const want = int64(1563129125000)
	if info.TakenAt != want {
		t.Fatalf("got %d, want %d", info.TakenAt, want)
	}
}

func TestProbeFallsBackToPlainDateTime(t *testing.T) {
	data := jpegWithExif(t, 100, 50, map[uint16]string{
		tagDateTime: "2020:01:02 03:04:05",
	}, 0)

	info, err := Probe(writeTemp(t, "scan.jpg", data))
	if err != nil {
		t.Fatalf("probing: %v", err)
	}
	if info.TakenAt == 0 {
		t.Fatal("DateTime was ignored, so a scan would sort by upload time instead")
	}
}

func TestProbeSwapsDimensionsForARotatedPhoto(t *testing.T) {
	// orientation 6 means the stored pixels are a quarter turn from how the
	// picture is meant to be seen. A grid laid out from the stored dimensions
	// would put a portrait photo in a landscape slot
	data := jpegWithExif(t, 400, 300, nil, 6)

	info, err := Probe(writeTemp(t, "rotated.jpg", data))
	if err != nil {
		t.Fatalf("probing: %v", err)
	}
	if info.Width != 300 || info.Height != 400 {
		t.Fatalf("got %dx%d, want 300x400 after the rotation", info.Width, info.Height)
	}
}

func TestProbeDoesNotSwapForAnUprightPhoto(t *testing.T) {
	data := jpegWithExif(t, 400, 300, nil, 1)

	info, err := Probe(writeTemp(t, "upright.jpg", data))
	if err != nil {
		t.Fatalf("probing: %v", err)
	}
	if info.Width != 400 || info.Height != 300 {
		t.Fatalf("got %dx%d, want 400x300 unchanged", info.Width, info.Height)
	}
}

func TestProbeSurvivesGarbage(t *testing.T) {
	// this parser runs on whatever anyone uploads, so the failure mode that
	// matters is not "wrong answer" but "panic" or "allocate a gigabyte"
	cases := map[string][]byte{
		"empty":            {},
		"soi only":         {0xFF, 0xD8},
		"truncated app1":   {0xFF, 0xD8, 0xFF, 0xE1, 0xFF, 0xFF, 'E', 'x'},
		"bogus tiff order": append([]byte{0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x10}, []byte("Exif\x00\x00ZZ\x00\x2a\x00\x00")...),
		"claims huge ifd":  append([]byte{0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x12}, []byte("Exif\x00\x00MM\x00\x2a\x00\x00\x00\x08\xff\xff")...),
	}

	for name, data := range cases {
		t.Run(name, func(t *testing.T) {
			path := writeTemp(t, "junk.jpg", data)
			// an error is the expected outcome; not returning is not
			_, _ = Probe(path)
		})
	}
}

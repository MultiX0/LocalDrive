// Package media reads the two facts a photo grid needs and nothing else:
// how big the picture is, and when it was actually taken.
//
// Dimensions let a client lay out a masonry grid before a single thumbnail has
// arrived, which is the difference between a grid that settles instantly and
// one that reflows as images load.
//
// Capture time is a genuinely different thing from upload time. A photo taken
// in 2019 and uploaded today has a created_at of today, and a gallery sorted
// by that puts it at the top, which is wrong. When a file carries no capture
// time this says so rather than inventing one.
package media

import (
	"encoding/binary"
	"errors"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"os"
	"time"

	_ "golang.org/x/image/bmp"
	_ "golang.org/x/image/tiff"
	_ "golang.org/x/image/webp"
)

// Info is what one image file can tell us about itself.
type Info struct {
	Width  int
	Height int

	// TakenAt is zero when the file carries no capture time, which is the
	// common case for anything that is not a camera photo.
	TakenAt int64
}

// Probe reads dimensions, and a capture time when the file has one.
//
// It decodes only the header, never the pixels, so this costs the same on a
// forty megapixel raw as on a thumbnail.
func Probe(path string) (Info, error) {
	f, err := os.Open(path)
	if err != nil {
		return Info{}, err
	}
	defer f.Close()

	config, _, err := image.DecodeConfig(f)
	if err != nil {
		return Info{}, err
	}
	info := Info{Width: config.Width, Height: config.Height}

	if _, err := f.Seek(0, io.SeekStart); err != nil {
		return info, nil
	}
	if taken, err := captureTime(f); err == nil {
		info.TakenAt = taken.UnixMilli()
	}

	// EXIF orientation can mean the stored pixels are rotated relative to how
	// the picture is meant to be seen. A grid laid out from the stored
	// dimensions would then put a portrait photo in a landscape slot
	if _, err := f.Seek(0, io.SeekStart); err == nil {
		if o, err := orientation(f); err == nil && o >= 5 && o <= 8 {
			info.Width, info.Height = info.Height, info.Width
		}
	}
	return info, nil
}

var errNoExif = errors.New("media: no exif")

// captureTime reads DateTimeOriginal, falling back to the file's own DateTime.
func captureTime(r io.ReadSeeker) (time.Time, error) {
	value, err := exifString(r, tagDateTimeOriginal, tagDateTime)
	if err != nil {
		return time.Time{}, err
	}
	// EXIF writes "2019:07:14 18:32:05", with no zone. It is local time to
	// wherever the photo was taken, and there is nothing in the file that says
	// where that was, so it is read as UTC rather than as this server's zone,
	// which would shift every photo by however the server happens to be set
	moment, err := time.ParseInLocation("2006:01:02 15:04:05", value, time.UTC)
	if err != nil {
		return time.Time{}, err
	}
	return moment, nil
}

func orientation(r io.ReadSeeker) (int, error) {
	return exifShort(r, tagOrientation)
}

const (
	tagOrientation      = 0x0112
	tagDateTime         = 0x0132
	tagDateTimeOriginal = 0x9003
	tagExifIFD          = 0x8769

	typeASCII = 2
	typeShort = 3
)

// exifReader is the parsed TIFF header inside a JPEG's APP1 segment.
type exifReader struct {
	data  []byte
	order binary.ByteOrder
}

func exifString(r io.ReadSeeker, tags ...uint16) (string, error) {
	e, err := openExif(r)
	if err != nil {
		return "", err
	}
	for _, tag := range tags {
		if value, ok := e.ascii(tag); ok {
			return value, nil
		}
	}
	return "", errNoExif
}

func exifShort(r io.ReadSeeker, tag uint16) (int, error) {
	e, err := openExif(r)
	if err != nil {
		return 0, err
	}
	if value, ok := e.short(tag); ok {
		return value, nil
	}
	return 0, errNoExif
}

// openExif finds the APP1 segment of a JPEG and returns its TIFF block.
//
// Only JPEG is walked. It is the format cameras and phones actually write
// EXIF into, and every other format here either has no capture time or stores
// it somewhere that would need a second parser to reach.
func openExif(r io.ReadSeeker) (*exifReader, error) {
	header := make([]byte, 2)
	if _, err := io.ReadFull(r, header); err != nil {
		return nil, errNoExif
	}
	// SOI
	if header[0] != 0xFF || header[1] != 0xD8 {
		return nil, errNoExif
	}

	marker := make([]byte, 4)
	for {
		if _, err := io.ReadFull(r, marker); err != nil {
			return nil, errNoExif
		}
		if marker[0] != 0xFF {
			return nil, errNoExif
		}
		// start of scan: past here is compressed pixels, not metadata
		if marker[1] == 0xDA {
			return nil, errNoExif
		}

		length := int(binary.BigEndian.Uint16(marker[2:4]))
		if length < 2 {
			return nil, errNoExif
		}
		payload := length - 2

		// a segment large enough to be a decompression bomb is refused rather
		// than allocated: this runs on whatever anyone uploads
		if payload > 1<<20 {
			if _, err := r.Seek(int64(payload), io.SeekCurrent); err != nil {
				return nil, errNoExif
			}
			continue
		}

		if marker[1] != 0xE1 {
			if _, err := r.Seek(int64(payload), io.SeekCurrent); err != nil {
				return nil, errNoExif
			}
			continue
		}

		body := make([]byte, payload)
		if _, err := io.ReadFull(r, body); err != nil {
			return nil, errNoExif
		}
		// "Exif\0\0", then the TIFF block
		if len(body) < 14 || string(body[0:4]) != "Exif" {
			continue
		}
		return newExifReader(body[6:])
	}
}

func newExifReader(tiff []byte) (*exifReader, error) {
	if len(tiff) < 8 {
		return nil, errNoExif
	}
	var order binary.ByteOrder
	switch string(tiff[0:2]) {
	case "II":
		order = binary.LittleEndian
	case "MM":
		order = binary.BigEndian
	default:
		return nil, errNoExif
	}
	if order.Uint16(tiff[2:4]) != 42 {
		return nil, errNoExif
	}
	return &exifReader{data: tiff, order: order}, nil
}

// ascii finds one string tag, looking in the main IFD and then in the Exif
// sub-IFD it points at, which is where DateTimeOriginal actually lives.
func (e *exifReader) ascii(tag uint16) (string, bool) {
	entry, ok := e.find(tag)
	if !ok || entry.format != typeASCII {
		return "", false
	}
	raw, ok := e.bytesAt(entry)
	if !ok {
		return "", false
	}
	// EXIF strings are NUL terminated and the count includes the terminator
	for i, b := range raw {
		if b == 0 {
			return string(raw[:i]), true
		}
	}
	return string(raw), true
}

func (e *exifReader) short(tag uint16) (int, bool) {
	entry, ok := e.find(tag)
	if !ok || entry.format != typeShort {
		return 0, false
	}
	if len(entry.inline) < 2 {
		return 0, false
	}
	return int(e.order.Uint16(entry.inline[:2])), true
}

type exifEntry struct {
	format uint16
	count  uint32
	inline []byte
}

func (e *exifReader) find(tag uint16) (exifEntry, bool) {
	offset := e.order.Uint32(e.data[4:8])
	seen := 0

	for offset != 0 && seen < 8 {
		seen++
		entry, next, sub, found := e.scanIFD(offset, tag)
		if found {
			return entry, true
		}
		// the Exif sub-IFD, when this IFD named one
		if sub != 0 {
			if entry, _, _, found := e.scanIFD(sub, tag); found {
				return entry, true
			}
		}
		offset = next
	}
	return exifEntry{}, false
}

func (e *exifReader) scanIFD(offset uint32, tag uint16) (entry exifEntry, next uint32, sub uint32, found bool) {
	if int(offset)+2 > len(e.data) {
		return exifEntry{}, 0, 0, false
	}
	count := int(e.order.Uint16(e.data[offset : offset+2]))
	base := int(offset) + 2

	for i := range count {
		at := base + i*12
		if at+12 > len(e.data) {
			return exifEntry{}, 0, 0, false
		}
		id := e.order.Uint16(e.data[at : at+2])
		if id == tagExifIFD {
			sub = e.order.Uint32(e.data[at+8 : at+12])
		}
		if id != tag {
			continue
		}
		entry = exifEntry{
			format: e.order.Uint16(e.data[at+2 : at+4]),
			count:  e.order.Uint32(e.data[at+4 : at+8]),
			inline: e.data[at+8 : at+12],
		}
		found = true
	}

	nextAt := base + count*12
	if nextAt+4 <= len(e.data) {
		next = e.order.Uint32(e.data[nextAt : nextAt+4])
	}
	return entry, next, sub, found
}

// bytesAt resolves a value that did not fit in the entry's own four bytes.
func (e *exifReader) bytesAt(entry exifEntry) ([]byte, bool) {
	size := entry.count // ASCII is one byte per element
	if size <= 4 {
		return entry.inline[:size], true
	}
	offset := e.order.Uint32(entry.inline)
	if int(offset)+int(size) > len(e.data) {
		return nil, false
	}
	return e.data[offset : offset+size], true
}

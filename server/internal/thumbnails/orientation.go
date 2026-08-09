package thumbnails

import (
	"encoding/binary"
	"image"
	"image/draw"
	"io"
	"os"
)

// Orientation is the EXIF tag a camera writes instead of rotating the pixels.
//
// A phone held sideways stores the sensor's landscape frame and records how it
// was held. Anything that decodes the pixels and ignores the tag gets a picture
// lying on its side, which is why thumbnails came out rotated a quarter turn
// while the same file looked upright everywhere else. Go's image package does
// not read EXIF, so this does.
type Orientation int

const (
	OrientationNormal Orientation = 1
	orientationFlipH  Orientation = 2
	orientation180    Orientation = 3
	orientationFlipV  Orientation = 4
	orientationTransp Orientation = 5
	orientation90     Orientation = 6
	orientationTransv Orientation = 7
	orientation270    Orientation = 8
)

// readOrientation pulls the tag out of a JPEG without decoding the image.
//
// It walks the segment markers to the APP1 that starts with "Exif", then reads
// the little TIFF structure inside it far enough to find tag 0x0112. Anything
// unexpected returns normal: a thumbnail that is not rotated is a much smaller
// problem than one that fails to generate.
func readOrientation(path string) Orientation {
	f, err := os.Open(path)
	if err != nil {
		return OrientationNormal
	}
	defer f.Close()

	header := make([]byte, 2)
	if _, err := io.ReadFull(f, header); err != nil {
		return OrientationNormal
	}
	// not a JPEG, so no EXIF to find
	if header[0] != 0xFF || header[1] != 0xD8 {
		return OrientationNormal
	}

	for {
		marker := make([]byte, 4)
		if _, err := io.ReadFull(f, marker); err != nil {
			return OrientationNormal
		}
		if marker[0] != 0xFF {
			return OrientationNormal
		}
		size := int(binary.BigEndian.Uint16(marker[2:4]))
		if size < 2 {
			return OrientationNormal
		}
		// APP1 is the only segment EXIF lives in
		if marker[1] != 0xE1 {
			if _, err := f.Seek(int64(size-2), io.SeekCurrent); err != nil {
				return OrientationNormal
			}
			continue
		}

		body := make([]byte, size-2)
		if _, err := io.ReadFull(f, body); err != nil {
			return OrientationNormal
		}
		return orientationIn(body)
	}
}

func orientationIn(app1 []byte) Orientation {
	if len(app1) < 14 || string(app1[:4]) != "Exif" {
		return OrientationNormal
	}
	tiff := app1[6:]
	if len(tiff) < 8 {
		return OrientationNormal
	}

	var order binary.ByteOrder
	switch {
	case tiff[0] == 'I' && tiff[1] == 'I':
		order = binary.LittleEndian
	case tiff[0] == 'M' && tiff[1] == 'M':
		order = binary.BigEndian
	default:
		return OrientationNormal
	}

	offset := int(order.Uint32(tiff[4:8]))
	if offset < 8 || offset+2 > len(tiff) {
		return OrientationNormal
	}

	count := int(order.Uint16(tiff[offset : offset+2]))
	entry := offset + 2
	for i := 0; i < count; i++ {
		if entry+12 > len(tiff) {
			return OrientationNormal
		}
		if order.Uint16(tiff[entry:entry+2]) == 0x0112 {
			value := Orientation(order.Uint16(tiff[entry+8 : entry+10]))
			if value >= OrientationNormal && value <= orientation270 {
				return value
			}
			return OrientationNormal
		}
		entry += 12
	}
	return OrientationNormal
}

// applyOrientation turns the decoded pixels the way the camera was held.
func applyOrientation(src image.Image, o Orientation) image.Image {
	if o <= OrientationNormal || o > orientation270 {
		return src
	}

	b := src.Bounds()
	w, h := b.Dx(), b.Dy()

	// the quarter turns swap the sides
	turned := o == orientation90 || o == orientation270 ||
		o == orientationTransp || o == orientationTransv
	dstW, dstH := w, h
	if turned {
		dstW, dstH = h, w
	}

	dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			var nx, ny int
			switch o {
			case orientationFlipH:
				nx, ny = w-1-x, y
			case orientation180:
				nx, ny = w-1-x, h-1-y
			case orientationFlipV:
				nx, ny = x, h-1-y
			case orientationTransp:
				nx, ny = y, x
			case orientation90:
				nx, ny = h-1-y, x
			case orientationTransv:
				nx, ny = h-1-y, w-1-x
			case orientation270:
				nx, ny = y, w-1-x
			default:
				nx, ny = x, y
			}
			dst.Set(nx, ny, src.At(b.Min.X+x, b.Min.Y+y))
		}
	}
	_ = draw.Src
	return dst
}

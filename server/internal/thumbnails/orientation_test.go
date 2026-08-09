package thumbnails

import (
	"image"
	"image/color"
	"testing"
)

// A picture taken with the phone on its side must come out upright.
func TestApplyOrientationTurnsTheQuarterTurns(t *testing.T) {
	// 2 wide, 1 tall, so a rotation is visible in the bounds alone
	src := image.NewRGBA(image.Rect(0, 0, 2, 1))
	src.Set(0, 0, color.RGBA{R: 255, A: 255})
	src.Set(1, 0, color.RGBA{B: 255, A: 255})

	turned := applyOrientation(src, orientation90)
	if got := turned.Bounds(); got.Dx() != 1 || got.Dy() != 2 {
		t.Fatalf("a quarter turn should swap the sides, got %v", got)
	}

	// the red pixel led on the left, so after a clockwise turn it is on top
	if r, _, _, _ := turned.At(0, 0).RGBA(); r == 0 {
		t.Fatal("the leading pixel did not end up where a clockwise turn puts it")
	}
}

func TestApplyOrientationLeavesNormalAlone(t *testing.T) {
	src := image.NewRGBA(image.Rect(0, 0, 3, 2))
	if got := applyOrientation(src, OrientationNormal); got != src {
		t.Fatal("an upright picture should not be copied or altered")
	}
}

func TestApplyOrientationHandlesTheFlips(t *testing.T) {
	src := image.NewRGBA(image.Rect(0, 0, 2, 1))
	src.Set(0, 0, color.RGBA{R: 255, A: 255})

	flipped := applyOrientation(src, orientationFlipH)
	if r, _, _, _ := flipped.At(1, 0).RGBA(); r == 0 {
		t.Fatal("a horizontal flip should move the left pixel to the right")
	}
}

// Anything that is not a JPEG, or has no tag, must read as upright rather than
// failing: a thumbnail that is not rotated beats one that never generates.
func TestReadOrientationFallsBackToNormal(t *testing.T) {
	if got := readOrientation("does-not-exist.jpg"); got != OrientationNormal {
		t.Fatalf("a missing file should read as normal, got %d", got)
	}
}

func TestOrientationInRejectsRubbish(t *testing.T) {
	for _, bad := range [][]byte{
		nil,
		[]byte("not exif at all"),
		[]byte("Exif\x00\x00XX"),
	} {
		if got := orientationIn(bad); got != OrientationNormal {
			t.Fatalf("rubbish should read as normal, got %d", got)
		}
	}
}

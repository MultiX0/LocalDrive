package storage

import (
	"errors"
	"os"
	"runtime"
	"syscall"
)

// windows returns ERROR_NOT_SAME_DEVICE for a rename across volumes
const errorNotSameDevice = syscall.Errno(17)

// isCrossDevice reports whether a rename failed only because source and
// destination sit on different filesystems, which is the one case where a
// copy is the correct fallback.
func isCrossDevice(err error) bool {
	var le *os.LinkError
	if errors.As(err, &le) {
		err = le.Err
	}
	if errors.Is(err, syscall.EXDEV) {
		return true
	}
	if runtime.GOOS == "windows" {
		var errno syscall.Errno
		if errors.As(err, &errno) && errno == errorNotSameDevice {
			return true
		}
	}
	return false
}

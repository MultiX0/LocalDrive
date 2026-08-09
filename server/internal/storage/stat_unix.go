//go:build !windows

package storage

import (
	"fmt"
	"os"
	"syscall"
)

// diskUsage reads live total and free bytes from the filesystem backing path.
func diskUsage(path string) (total, free int64, err error) {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err != nil {
		return 0, 0, fmt.Errorf("storage: statfs %s: %w", path, err)
	}
	bsize := int64(st.Bsize)
	total = int64(st.Blocks) * bsize
	free = int64(st.Bavail) * bsize
	return total, free, nil
}

// deviceIdentity returns the device number backing path, which changes the
// moment a removable drive is unplugged and something else is mounted there.
func deviceIdentity(path string) (string, error) {
	info, err := os.Stat(path)
	if err != nil {
		return "", err
	}
	st, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return "", fmt.Errorf("storage: no device information for %s", path)
	}
	return fmt.Sprintf("dev:%d", uint64(st.Dev)), nil
}

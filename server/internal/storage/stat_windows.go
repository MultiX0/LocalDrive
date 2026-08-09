//go:build windows

package storage

import (
	"fmt"
	"path/filepath"
	"syscall"
	"unsafe"
)

var (
	kernel32               = syscall.NewLazyDLL("kernel32.dll")
	procGetDiskFreeSpaceEx = kernel32.NewProc("GetDiskFreeSpaceExW")
	procGetVolumeInfo      = kernel32.NewProc("GetVolumeInformationW")
)

// diskUsage reads live total and free bytes for the volume backing path.
// Windows is a development target only; production runs in Linux containers.
func diskUsage(path string) (total, free int64, err error) {
	ptr, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return 0, 0, err
	}
	var freeToCaller, totalBytes, totalFree uint64
	r, _, callErr := procGetDiskFreeSpaceEx.Call(
		uintptr(unsafe.Pointer(ptr)),
		uintptr(unsafe.Pointer(&freeToCaller)),
		uintptr(unsafe.Pointer(&totalBytes)),
		uintptr(unsafe.Pointer(&totalFree)),
	)
	if r == 0 {
		return 0, 0, fmt.Errorf("storage: disk space for %s: %w", path, callErr)
	}
	return int64(totalBytes), int64(freeToCaller), nil
}

// deviceIdentity returns the volume serial number backing path.
func deviceIdentity(path string) (string, error) {
	vol := filepath.VolumeName(path)
	if vol == "" {
		return "", fmt.Errorf("storage: no volume for %s", path)
	}
	root, err := syscall.UTF16PtrFromString(vol + `\`)
	if err != nil {
		return "", err
	}
	var serial, maxComponent, flags uint32
	nameBuf := make([]uint16, 261)
	fsBuf := make([]uint16, 261)
	r, _, callErr := procGetVolumeInfo.Call(
		uintptr(unsafe.Pointer(root)),
		uintptr(unsafe.Pointer(&nameBuf[0])), uintptr(len(nameBuf)),
		uintptr(unsafe.Pointer(&serial)),
		uintptr(unsafe.Pointer(&maxComponent)),
		uintptr(unsafe.Pointer(&flags)),
		uintptr(unsafe.Pointer(&fsBuf[0])), uintptr(len(fsBuf)),
	)
	if r == 0 {
		return "", fmt.Errorf("storage: volume information for %s: %w", vol, callErr)
	}
	return fmt.Sprintf("vol:%08X", serial), nil
}

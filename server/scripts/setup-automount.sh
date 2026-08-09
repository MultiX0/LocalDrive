#!/usr/bin/env bash
# Host level automount, the alternative for a deployer who would rather not
# grant the mount-helper container SYS_ADMIN at all.
#
# Run this once on the host, outside Docker. Afterwards a plugged in USB drive
# is mounted under /srv/localdrive/external by udev, and the backend picks it
# up exactly as it would from the helper, so both paths land in the same
# Detected Drives screen. The only difference is that the initial plug in step
# needs this one time host setup instead of being triggered from the app.
#
#   sudo scripts/setup-automount.sh

set -euo pipefail

MOUNT_ROOT="${MOUNT_ROOT:-/srv/localdrive/external}"
CONTAINER_UID="${CONTAINER_UID:-10001}"
CONTAINER_GID="${CONTAINER_GID:-10001}"

if [ "$(id -u)" -ne 0 ]; then
	echo "this needs to run as root, try: sudo $0" >&2
	exit 1
fi

if ! command -v udevadm >/dev/null 2>&1; then
	echo "this host does not use udev, so there is nothing for this script to install." >&2
	echo "mount your drives under $MOUNT_ROOT however this system normally does it." >&2
	exit 1
fi

echo "1. creating $MOUNT_ROOT"
mkdir -p "$MOUNT_ROOT"
chown "$CONTAINER_UID:$CONTAINER_GID" "$MOUNT_ROOT"
chmod 755 "$MOUNT_ROOT"

# the mount root is shared so mounts made on the host propagate into the
# container, which is what makes a newly plugged drive visible without a
# restart
if ! findmnt -no PROPAGATION "$MOUNT_ROOT" 2>/dev/null | grep -q shared; then
	echo "   making $MOUNT_ROOT a shared mount"
	mount --bind "$MOUNT_ROOT" "$MOUNT_ROOT"
	mount --make-rshared "$MOUNT_ROOT"
fi

echo "2. installing the mount helper script"
cat > /usr/local/sbin/localdrive-automount <<'HELPER'
#!/usr/bin/env bash
# Called by udev when a USB storage partition appears or goes away.
set -euo pipefail

MOUNT_ROOT="/srv/localdrive/external"
CONTAINER_UID="10001"
CONTAINER_GID="10001"

action="${1:-}"
device="${2:-}"

[ -n "$action" ] && [ -n "$device" ] || exit 0
[ -b "/dev/$device" ] || exit 0

label="$(lsblk -no LABEL "/dev/$device" 2>/dev/null | head -1 | tr -cd 'A-Za-z0-9._-')"
uuid="$(lsblk -no UUID "/dev/$device" 2>/dev/null | head -1 | tr -cd 'A-Za-z0-9-')"
name="${label:-$uuid}"
name="${name:-$device}"
target="$MOUNT_ROOT/$name"

case "$action" in
add)
	fstype="$(lsblk -no FSTYPE "/dev/$device" 2>/dev/null | head -1)"
	case "$fstype" in
	ext4 | ext3 | ext2 | xfs | btrfs | f2fs)
		options="noatime,nodev,nosuid,noexec"
		;;
	vfat | exfat | ntfs)
		options="noatime,nodev,nosuid,noexec,uid=$CONTAINER_UID,gid=$CONTAINER_GID,umask=002"
		;;
	*)
		# no filesystem this host can mount; the app offers to format it
		exit 0
		;;
	esac
	mkdir -p "$target"
	mount -o "$options" "/dev/$device" "$target" || exit 0
	if [ "$fstype" != "vfat" ] && [ "$fstype" != "exfat" ] && [ "$fstype" != "ntfs" ]; then
		chown "$CONTAINER_UID:$CONTAINER_GID" "$target"
	fi
	logger -t localdrive-automount "mounted /dev/$device at $target"
	;;
remove)
	if mountpoint -q "$target"; then
		umount -l "$target" || true
	fi
	rmdir "$target" 2>/dev/null || true
	logger -t localdrive-automount "released $target"
	;;
esac
HELPER
chmod 755 /usr/local/sbin/localdrive-automount

echo "3. installing the udev rule"
cat > /etc/udev/rules.d/99-localdrive-automount.rules <<'RULE'
# Local Drive: mount usb storage partitions under /srv/localdrive/external
ACTION=="add", KERNEL=="sd[a-z][0-9]", SUBSYSTEMS=="usb", ENV{ID_FS_TYPE}!="", \
  RUN+="/usr/local/sbin/localdrive-automount add %k"
ACTION=="remove", KERNEL=="sd[a-z][0-9]", SUBSYSTEMS=="usb", \
  RUN+="/usr/local/sbin/localdrive-automount remove %k"
RULE

echo "4. installing the systemd unit so mounts survive a reboot"
cat > /etc/systemd/system/localdrive-mounts.service <<UNIT
[Unit]
Description=Local Drive external mount root
DefaultDependencies=no
After=local-fs.target
Before=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/mkdir -p $MOUNT_ROOT
ExecStart=/usr/bin/mount --bind $MOUNT_ROOT $MOUNT_ROOT
ExecStart=/usr/bin/mount --make-rshared $MOUNT_ROOT

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now localdrive-mounts.service

echo "5. reloading udev"
udevadm control --reload-rules
udevadm trigger --subsystem-match=block --action=add

echo
echo "Done. Plug a drive in and it will appear under Detected drives in the app."
echo "You can now leave mount-helper out of docker-compose.yml if you prefer,"
echo "and clear MOUNT_HELPER_SOCKET in .env."

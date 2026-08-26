#!/bin/bash
set -e

log() {
  echo "[rpi-expand-rootfs] $*" | tee -a /var/log/rpi-expand-rootfs.log
}

log "Starting root filesystem expansion..."

# Find the root partition device
ROOT_PARTITION=$(findmnt -n -o SOURCE /)
ROOT_DEVICE="${ROOT_PARTITION%p*}"
PARTITION_NUM="${ROOT_PARTITION##*p}"

if [ -z "$ROOT_PARTITION" ] || [ -z "$PARTITION_NUM" ]; then
  log "ERROR: Could not determine root partition"
  exit 1
fi

log "Root partition: $ROOT_PARTITION"
log "Root device: $ROOT_DEVICE"

# Expand partition to fill disk
log "Expanding partition $PARTITION_NUM..."
parted -s "$ROOT_DEVICE" resizepart "$PARTITION_NUM" 100%

# Wait for kernel to recognize the change
sleep 1

# Resize the filesystem
log "Resizing filesystem..."
if grep -q ext4 /proc/filesystems && [ "$(lsblk -no FSTYPE "$ROOT_PARTITION")" = "ext4" ]; then
  resize2fs "$ROOT_PARTITION"
elif grep -q btrfs /proc/filesystems && [ "$(lsblk -no FSTYPE "$ROOT_PARTITION")" = "btrfs" ]; then
  btrfs filesystem resize max /
fi

# Mark that expansion has been done
touch /home/assistant/.rpi-expanded

log "Root filesystem expansion complete"

#!/bin/bash
set -e

echo "Starting root filesystem expansion..."

ROOT_PARTITION="$(realpath "$(findmnt -n -o SOURCE /)")"
ROOT_DEVICE=$(echo "$ROOT_PARTITION" | sed -E 's/p?[0-9]+$//')
PARTITION_NUM=$(echo "$ROOT_PARTITION" | grep -o '[0-9]\+$')

if [ -z "$ROOT_PARTITION" ] || [ -z "$PARTITION_NUM" ] || [ -z "$ROOT_DEVICE" ]; then
  echo "ERROR: Could not determine root partition"
  exit 1
fi

echo "Root partition: $ROOT_PARTITION"
echo "Root device: $ROOT_DEVICE"
echo "Partition number: $PARTITION_NUM"

echo "Expanding partition..."
growpart "$ROOT_DEVICE" "$PARTITION_NUM"

sleep 1

echo "Resizing filesystem..."
resize2fs "$ROOT_PARTITION"

echo "Placing marker..."
touch /home/assistant/.rpi-expanded

echo "Root filesystem expansion complete"

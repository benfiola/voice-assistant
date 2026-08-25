#!/bin/bash
set -e

# Voice Assistant rpi-image-gen build script
# Usage: ./build-rpi-image.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Env file not found: $ENV_FILE"
  echo "Copy .example.env to .env and fill in your settings"
  exit 1
fi
source "$ENV_FILE"

# Validate required variables
for var in HOSTNAME PASSWORD; do
  if [ -z "${!var:-}" ]; then
    echo "❌ $var not set in $ENV_FILE"
    exit 1
  fi
done

WORK_DIR="${WORK_DIR:-/tmp/voice-assistant-build}"
OUTPUT_IMAGE="$SCRIPT_DIR/.dist/${HOSTNAME}.img"

echo "📦 Building Voice Assistant image..."
echo "  Hostname: $HOSTNAME"
echo "  Work: $WORK_DIR"
echo "  Output: $OUTPUT_IMAGE"

# Build the image using rpi-image-gen
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
rpi-image-gen build \
  -c "$SCRIPT_DIR/rpi-image-gen/config/voice-assistant.yaml" \
  -S "$SCRIPT_DIR/rpi-image-gen" \
  -B "$WORK_DIR" \
  -- \
  "IGconf_device_hostname=$HOSTNAME" \
  "IGconf_device_user1pass=$PASSWORD" \
  "IGconf_wifi_password=$WIFI_PASSWORD"

BUILD_IMAGE="$WORK_DIR/image-voice-assistant/voice-assistant.img"
if [ -f "$BUILD_IMAGE" ]; then
  mkdir -p "$(dirname "$OUTPUT_IMAGE")"
  mv "$BUILD_IMAGE" "$OUTPUT_IMAGE"
  echo "✨ Image ready: $OUTPUT_IMAGE"
else
  echo "❌ Build finished but no image was found at: $BUILD_IMAGE"
  exit 1
fi

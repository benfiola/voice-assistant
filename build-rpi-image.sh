#!/bin/bash
set -e

# Voice Assistant rpi-image-gen build script
# Usage: ./build-rpi-image.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/voice-assistant-build}"

# Load environment variables
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

echo "📦 Building Voice Assistant image..."
echo "  Hostname: $HOSTNAME"
echo "  Output: $OUTPUT_DIR"

# Build the image using rpi-image-gen
mkdir -p "$OUTPUT_DIR"
set -x
rpi-image-gen build \
  -c "$SCRIPT_DIR/rpi-image-gen/config/voice-assistant.yaml" \
  -S "$SCRIPT_DIR/rpi-image-gen" \
  -B "$OUTPUT_DIR" \
  -- \
  "IGconf_device_hostname=$HOSTNAME" \
  "IGconf_device_user1pass=$PASSWORD" \
  "IGconf_wifi_password=$WIFI_PASSWORD"

mkdir -p "$SCRIPT_DIR/work"
FINAL_IMAGE="$SCRIPT_DIR/.dist/${HOSTNAME}.img"
BUILD_IMAGE="$OUTPUT_DIR/voice-assistant/voice-assistant.img"

if [ -f "$BUILD_IMAGE" ]; then
  mv "$BUILD_IMAGE" "$FINAL_IMAGE"
  echo "✨ Image ready: $FINAL_IMAGE"
else
  echo "✨ Build completed. Image in: $OUTPUT_DIR"
fi

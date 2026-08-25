#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt -y update
apt -y install \
  git \
  qemu-user \
  binfmt-support \
  python3-yaml

# Install rpi-image-gen
if [ ! -d "$HOME/.local/share/rpi-image-gen" ]; then
  echo "Installing rpi-image-gen..."
  git clone https://github.com/raspberrypi/rpi-image-gen.git "$HOME/.local/share/rpi-image-gen"
  cd "$HOME/.local/share/rpi-image-gen"
  ./install_deps.sh
  cd -
fi
export PATH="$HOME/.local/share/rpi-image-gen:$PATH"
echo 'export PATH="$HOME/.local/share/rpi-image-gen:$PATH"' >> ~/.bashrc
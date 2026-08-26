#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt -y update
apt -y install \
  git \
  qemu-user \
  binfmt-support \
  python3-yaml

echo "Installing rpi-image-gen..."
mkdir -p /opt
git clone https://github.com/raspberrypi/rpi-image-gen.git /opt/rpi-image-gen
cd /opt/rpi-image-gen
git checkout v2.8.0
./install_deps.sh
ln -s /opt/rpi-image-gen/rpi-image-gen /usr/local/bin/rpi-image-gen
cd -

#!/bin/sh
set -eu

REPO_DIR="/home/assistant/voice-assistant"
LVA_DIR="$REPO_DIR/vendor/linux-voice-assistant"
LEC_DIR="$REPO_DIR/led-controller"
APP_USER="assistant"
VENV_DIR="/home/$APP_USER/.venv"

# pull in latest code
git config --global --add safe.directory '*'
git -C "$REPO_DIR" pull --ff-only
git -C "$REPO_DIR" submodule update --init --recursive

# install packages
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  alsa-utils \
  avahi-utils \
  build-essential \
  ca-certificates \
  curl \
  dfu-util \
  git \
  iproute2 \
  jq \
  libasound2-plugins \
  libmpv-dev \
  libspa-0.2-bluetooth \
  pipewire \
  pipewire-alsa \
  pipewire-audio \
  pipewire-audio-client-libraries \
  pipewire-bin \
  pipewire-pulse \
  procps \
  pulseaudio-utils \
  python3-dev \
  python3-venv \
  vim \
  wget \
  wireplumber

# app user needs access to the audio device and the XVF3800 USB device
usermod -a -G audio,plugdev "$APP_USER"

# configure pipewire's clock rate
mkdir -p /etc/pipewire/pipewire.conf.d
cat <<-EOF > /etc/pipewire/pipewire.conf.d/linux-voice-assistant.conf
context.properties = {
    default.clock.rate = 16000
}
EOF

# enable linger
mkdir -p /var/lib/systemd/linger
touch "/var/lib/systemd/linger/$APP_USER"

# create/update venv
python3 -m venv "$VENV_DIR"
. "$VENV_DIR/bin/activate"
pip install --upgrade pip setuptools wheel

# install linux-voice-assistant python dependencies
pip install -e "$LVA_DIR"
chmod +x "$LVA_DIR/docker-entrypoint.sh"

# install respeaker-xvf3800 python dependencies
pip install pyusb libusb-package

# install led-controller python dependencies
pip install -e "$LEC_DIR"

# configure udev rules for respeaker-xvf3800
cat <<-EOF > /etc/udev/rules.d/99-respeaker-xvf3800.rules
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ATTR{idProduct}=="001a", MODE="0666", GROUP="plugdev"
EOF
if [ -d /run/systemd/system ]; then
  udevadm control --reload-rules
  udevadm trigger
fi

# set the app user as the owner of the repo and venv
chown -R "$APP_USER:$APP_USER" "$REPO_DIR" "$VENV_DIR"

# install/update system units
units=""
for unit in "$REPO_DIR"/systemd/*.service "$REPO_DIR"/systemd/*.timer; do
  [ -e "$unit" ] || continue
  install -m 0644 "$unit" /etc/systemd/system/
  systemctl enable "$(basename "$unit")"
  units="$units $(basename "$unit")"
done

if [ -n "$units" ] && [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  for unit in $units; do
    case "$unit" in
      *.service) systemctl restart "$unit" ;;
    esac
  done
fi

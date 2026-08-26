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
system_units_to_restart=""
for unit in "$REPO_DIR"/systemd/system/*.service "$REPO_DIR"/systemd/system/*.timer; do
  [ -e "$unit" ] || continue
  unit_name="$(basename "$unit")"
  unit_dest="/etc/systemd/system/$unit_name"

  if ! cmp -s "$unit" "$unit_dest" 2>/dev/null; then
    install -m 0644 "$unit" "$unit_dest"
    case "$unit_name" in
      *.service) system_units_to_restart="$system_units_to_restart $unit_name" ;;
    esac
  fi
  systemctl enable "$unit_name"
done

if [ -n "$system_units_to_restart" ] && [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  for unit in $system_units_to_restart; do
    systemctl restart "$unit"
  done
fi

# install/update user units
USER_CONFIG_DIR="/home/$APP_USER/.config/systemd/user"
WANTS_DIR="$USER_CONFIG_DIR/default.target.wants"
mkdir -p "$WANTS_DIR"

user_units_to_restart=""
user_session_available=$(sudo -u "$APP_USER" systemctl --user is-active --quiet 2>/dev/null && echo 1 || echo 0)

for unit in "$REPO_DIR"/systemd/user/*.service "$REPO_DIR"/systemd/user/*.timer; do
  [ -e "$unit" ] || continue
  unit_name="$(basename "$unit")"
  unit_dest="$USER_CONFIG_DIR/$unit_name"

  if ! cmp -s "$unit" "$unit_dest" 2>/dev/null; then
    install -m 0644 "$unit" "$unit_dest"
    case "$unit_name" in
      *.service) user_units_to_restart="$user_units_to_restart $unit_name" ;;
    esac
  fi

  if [ "$user_session_available" = "1" ]; then
    sudo -u "$APP_USER" systemctl --user enable "$unit_name"
  else
    # create enable symlink if no session
    ln -sf "../$unit_name" "$WANTS_DIR/$unit_name"
  fi
done

chown -R "$APP_USER:$APP_USER" "$USER_CONFIG_DIR"

if [ -n "$user_units_to_restart" ] && [ "$user_session_available" = "1" ]; then
  sudo -u "$APP_USER" systemctl --user daemon-reload
  for unit in $user_units_to_restart; do
    sudo -u "$APP_USER" systemctl --user restart "$unit"
  done
fi

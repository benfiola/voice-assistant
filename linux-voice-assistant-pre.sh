#!/bin/sh
set -eu

REPO_DIR="/home/assistant/voice-assistant"
VENV_DIR="/home/assistant/.venv"

"$VENV_DIR/bin/python3" "$REPO_DIR/vendor/respeaker-xvf3800/python_control/xvf_host.py" REBOOT --values 1
sleep 3

SINK_ID=$(wpctl status | grep -A 10 "Sinks:" | grep "reSpeaker XVF3800" | grep -oE '[0-9]+' | head -1)
if [ -n "$SINK_ID" ]; then
  wpctl set-volume "$SINK_ID" 1.0
fi

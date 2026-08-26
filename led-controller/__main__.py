#!/usr/bin/env python3
"""
Activates the XVF3800 LED ring only when linux voice assistant is listening.
"""

import asyncio
import json
import logging
import subprocess
import sys

import websockets

# configuration
LVA_URI = "ws://localhost:6055"
XVF_HOST = "/home/assistant/voice-assistant/vendor/respeaker-xvf3800/python_control/xvf_host.py"

# States during which the LED ring should be ON (DoA mode)
ACTIVE_STATES = {"wake_word_detected", "listening", "thinking", "tts_speaking"}

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(message)s")

current_state = "idle"


def set_led_effect(effect: int) -> None:
    """
    LED effect values: 0=off, 1=breath, 2=rainbow, 3=single color, 4=doa
    """
    try:
        subprocess.run(
            [sys.executable, XVF_HOST, "LED_EFFECT", str(effect)],
            check=True,
            capture_output=True,
            timeout=2,
        )
    except Exception as exc:  # noqa: BLE001 - log and continue, never crash the loop
        stderr = getattr(exc, "stderr", None)
        detail = stderr.decode(errors="replace").strip() if stderr else exc
        logging.warning("Failed to set LED_EFFECT %s: %s", effect, detail)


async def handle_events():
    global current_state
    while True:
        try:
            async with websockets.connect(LVA_URI) as ws:
                logging.info("Connected to LVA peripheral API")
                # Start from a known state: LEDs off until something happens
                set_led_effect(0)

                async for raw in ws:
                    msg = json.loads(raw)
                    event = msg.get("event", "")

                    if event == "snapshot":
                        # Initial state on connect - leave LEDs off, we'll
                        # react to the next real event.
                        continue

                    if event in ACTIVE_STATES:
                        if current_state not in ACTIVE_STATES:
                            logging.info("→ LEDs ON (doa) [%s]", event)
                            set_led_effect(4)  # doa
                        current_state = event

                    elif event in ("idle", "tts_finished"):
                        if current_state != "idle":
                            logging.info("→ LEDs OFF [%s]", event)
                            set_led_effect(0)
                        current_state = "idle"

                    elif event == "pipeline_error":
                        logging.info("→ pipeline error, LEDs OFF")
                        set_led_effect(0)
                        current_state = "idle"

        except Exception as exc:  # noqa: BLE001
            logging.warning("Disconnected from LVA (%s) - retrying in 3s", exc)
            await asyncio.sleep(3)


if __name__ == "__main__":
    asyncio.run(handle_events())
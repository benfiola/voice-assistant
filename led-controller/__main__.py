#!/usr/bin/env python3
"""
Activates the XVF3800 LED ring only when linux voice assistant is listening.
"""

import asyncio
import enum
import json
import logging
import subprocess
import sys
import time

import websockets

# configuration
LVA_URI = "ws://localhost:6055"
XVF_HOST = "/home/assistant/voice-assistant/vendor/respeaker-xvf3800/python_control/xvf_host.py"
INACTIVITY_TIMEOUT = 60  # seconds


class State(enum.Enum):
    Active = enum.auto()
    Idle = enum.auto()


# globals
current_state: State = State.Idle
last_activity_time = time.time()
logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(message)s")


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


async def check_inactivity_timeout():
    """Monitor for inactivity and turn off LEDs after timeout."""
    global current_state, last_activity_time
    while True:
        await asyncio.sleep(5)  # Check every 5 seconds
        if current_state == State.Active:
            elapsed = time.time() - last_activity_time
            if elapsed >= INACTIVITY_TIMEOUT:
                logging.info("→ LEDs OFF (inactivity timeout after %.0fs)", elapsed)
                set_led_effect(0)
                current_state = State.Idle


async def handle_events():
    global current_state
    while True:
        try:
            async with websockets.connect(LVA_URI) as ws:
                logging.info("Connected to LVA peripheral API")
                # Start from a known state: LEDs off until something happens
                set_led_effect(0)

                async for raw in ws:
                    global last_activity_time
                    msg = json.loads(raw)
                    event = msg.get("event", "")
                    last_activity_time = time.time()

                    if event == "snapshot":
                        # Initial state on connect - leave LEDs off, we'll
                        # react to the next real event.
                        continue

                    if event in ("wake_word_detected", "listening", "thinking", "tts_speaking"):
                        if current_state != State.Active:
                            logging.info("→ LEDs ON (doa) [%s]", event)
                            set_led_effect(4)  # doa
                        current_state = State.Active

                    elif event in ("idle", "tts_finished"):
                        if current_state != State.Idle:
                            logging.info("→ LEDs OFF [%s]", event)
                            set_led_effect(0)
                        current_state = State.Idle

                    elif event == "pipeline_error":
                        logging.info("→ pipeline error, LEDs OFF")
                        set_led_effect(0)
                        current_state = State.Idle

        except Exception as exc:  # noqa: BLE001
            logging.warning("Disconnected from LVA (%s) - retrying in 3s", exc)
            await asyncio.sleep(3)


async def main():
    """Run both event handler and inactivity timeout check concurrently."""
    await asyncio.gather(
        handle_events(),
        check_inactivity_timeout(),
    )


if __name__ == "__main__":
    asyncio.run(main())
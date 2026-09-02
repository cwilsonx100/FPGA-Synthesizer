"""
Controls the CD74HC4051 analog multiplexers' shared select lines from the Pi.

All muxes share S0/S1/S2, so one 3-bit index selects the same pot position on
every mux simultaneously. Driving select is 3 GPIOs total regardless of how
many muxes you add.

Default select GPIOs (BCM numbering): S0=17, S1=27, S2=22.

Auto-falls back to a no-op stub when RPi.GPIO/gpiozero is unavailable or
SYNTH_FAKE=1, so the app runs off-Pi.
"""
import os
import time

FAKE = os.environ.get("SYNTH_FAKE", "0") == "1"

_HAVE_GPIO = False
if not FAKE:
    try:
        from gpiozero import DigitalOutputDevice  # type: ignore
        _HAVE_GPIO = True
    except Exception:
        _HAVE_GPIO = False


class MuxSelect:
    # settle time after switching the select lines, before reading the ADC.
    # 10k pot through 130-ohm mux into the ADC S/H needs a few tens of us;
    # 60us is conservative and prevents channel-to-channel bleed.
    SETTLE_S = 60e-6

    def __init__(self, s0=17, s1=27, s2=22):
        self.simulated = FAKE or not _HAVE_GPIO
        self._index = -1
        if self.simulated:
            self.lines = None
            return
        self.lines = [
            DigitalOutputDevice(s0),
            DigitalOutputDevice(s1),
            DigitalOutputDevice(s2),
        ]

    def select(self, index: int):
        """Drive S0..S2 to `index` (0..7) and wait for the analog to settle."""
        index &= 0x7
        if index == self._index:
            return
        self._index = index
        if self.simulated:
            return
        for bit, line in enumerate(self.lines):
            if (index >> bit) & 1:
                line.on()
            else:
                line.off()
        time.sleep(self.SETTLE_S)

    def close(self):
        if self.lines:
            for l in self.lines:
                l.close()

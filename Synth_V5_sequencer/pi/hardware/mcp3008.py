"""
MCP3008 10-bit ADC reader over SPI (Raspberry Pi hardware SPI0, CE0).

Falls back to a simulator automatically when spidev is unavailable (e.g.
developing on Windows/Mac) or when SYNTH_FAKE=1 is set, so the whole app
runs and the GUI works without any hardware attached.
"""
import os
import math
import time

FAKE = os.environ.get("SYNTH_FAKE", "0") == "1"

try:
    import spidev  # type: ignore
    _HAVE_SPIDEV = True
except Exception:
    _HAVE_SPIDEV = False


class MCP3008:
    def __init__(self, bus=0, device=0, max_hz=1_350_000):
        self.simulated = FAKE or not _HAVE_SPIDEV
        self._t0 = time.time()
        if self.simulated:
            self.spi = None
            return
        self.spi = spidev.SpiDev()
        self.spi.open(bus, device)          # /dev/spidev0.0  -> CE0
        self.spi.max_speed_hz = max_hz
        self.spi.mode = 0b00

    def read(self, channel: int) -> int:
        """Return a 0..1023 reading for the given channel (0..7)."""
        if not (0 <= channel <= 7):
            raise ValueError("MCP3008 channel must be 0..7")

        if self.simulated:
            # Slow, distinct sine sweeps per channel so the GUI shows motion.
            t = time.time() - self._t0
            phase = (t * 0.15) + channel * 0.7
            return int((math.sin(phase) * 0.5 + 0.5) * 1023)

        # MCP3008 protocol: start bit, single-ended + channel, read 10 bits.
        cmd = [1, (8 + channel) << 4, 0]
        r = self.spi.xfer2(cmd)
        return ((r[1] & 3) << 8) | r[2]

    def read_all(self):
        return [self.read(ch) for ch in range(8)]

    def close(self):
        if self.spi:
            self.spi.close()

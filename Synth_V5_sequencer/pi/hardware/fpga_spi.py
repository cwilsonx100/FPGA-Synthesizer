"""
Writes parameter registers to the FPGA over SPI (Raspberry Pi SPI0, CE1).

Packet format (matches Spi_slave.v / Param_regfile.v):
    [ address, value_high_byte, value_low_byte ]
CE toggles per xfer, which frames each 3-byte write on the FPGA side.

Falls back to a logging stub when spidev is unavailable or SYNTH_FAKE=1.
"""
import os

FAKE = os.environ.get("SYNTH_FAKE", "0") == "1"

try:
    import spidev  # type: ignore
    _HAVE_SPIDEV = True
except Exception:
    _HAVE_SPIDEV = False


class FpgaSpi:
    def __init__(self, bus=0, device=1, max_hz=1_000_000, verbose=False):
        self.simulated = FAKE or not _HAVE_SPIDEV
        self.verbose = verbose
        self.last_log = {}
        if self.simulated:
            self.spi = None
            return
        self.spi = spidev.SpiDev()
        self.spi.open(bus, device)          # /dev/spidev0.1 -> CE1
        self.spi.max_speed_hz = max_hz
        self.spi.mode = 0b00

    def write_register(self, address: int, value: int):
        value &= 0xFFFF
        address &= 0xFF
        packet = [address, (value >> 8) & 0xFF, value & 0xFF]
        if self.simulated:
            if self.verbose and self.last_log.get(address) != value:
                print(f"[FAKE FPGA] reg 0x{address:02x} <- {value}")
            self.last_log[address] = value
            return
        self.spi.xfer2(packet)

    def close(self):
        if self.spi:
            self.spi.close()

"""
Register map, muxed-pot layout, and scaling. Single source of truth shared
conceptually with the FPGA Param_regfile.v.

Hardware: the PCB has 8x CD74HC4051 mux positions, one per MCP3008 channel,
all sharing select lines (index 0..7). Populate as few or as many as you like:
set ENABLED_MUX_CHANNELS to just the ADC channels whose mux is actually
soldered down. Unpopulated channels are skipped entirely, which also keeps the
scan fast.

A pot is addressed by (adc_channel, mux_index):

    slot = adc_channel * 8 + mux_index      (0..63)

PCB mux -> ADC channel map (from the KiCad netlist):
    U3 -> CH0    U10 -> CH1   U8  -> CH2   U4 -> CH3
    U11-> CH4    U6  -> CH5   U7  -> CH6   U9 -> CH7
"""
import math

FS = 48000  # audio sample rate (must match FPGA)

# ---- register addresses (must match Param_regfile.v) ----
REG = {
    "attack":        0x00,
    "decay":         0x01,
    "sustain":       0x02,
    "release":       0x03,
    "pulse_width":   0x04,
    "detune":        0x05,
    "filter_f":      0x06,
    "volume":        0x07,
    "waveform":      0x08,
    "voice_mask":    0x09,
    "mute":          0x0A,
    "filter_bypass": 0x0B,
    "osc_b":         0x0C,
    "filter_q":      0x0D,
    "filter_type":   0x0E,
}

# ---- WHICH MUXES ARE POPULATED -------------------------------------------
# The board has all 8 positions; list only the ADC channels you actually
# populated. Add a channel here when you solder that mux down - nothing else
# needs to change. Example: [0] for one mux, [0,1,2] for three, range(8) for all.
ENABLED_MUX_CHANNELS = list(range(8))

# PCB reference designator per ADC channel (for the GUI / documentation only)
MUX_REFDES = {0: "U3", 1: "U10", 2: "U8", 3: "U4",
              4: "U11", 5: "U6", 6: "U7", 7: "U9"}

MUX_ADC_CHANNELS = list(ENABLED_MUX_CHANNELS)   # scanned channels
MUX_COUNT = len(MUX_ADC_CHANNELS)
POT_COUNT = MUX_COUNT * 8
MAX_POT_COUNT = 64                              # if all 8 muxes populated


def slot_to_addr(adc_channel, mux_index):
    return adc_channel * 8 + mux_index


# ---- special scaling for the two filter knobs ----
def cutoff_to_f(v01):
    """Pot 0..1 -> SVF f coefficient (Q14). Log-mapped cutoff 30 Hz..7500 Hz.
       f = sin(pi*Fc/Fs) (calibrated to this filter)."""
    fmin, fmax = 30.0, 7500.0
    fc = fmin * (fmax / fmin) ** v01           # exponential/log sweep
    f_real = math.sin(math.pi * fc / FS)
    f_real = max(0.0, min(0.90, f_real))        # hard cap < 1.0 for SVF stability
    return int(round(f_real * 16384))          # Q14 (<= ~14746, safely < 16384)


def resonance_to_q(v01):
    """Pot 0..1 -> SVF q coefficient (Q14). q = 1/Q.
       Low pot = damped (q~1.4), high pot = very resonant (q small)."""
    qmin_res, qmax_res = 0.05, 1.5             # q_real range (small = resonant)
    # invert so clockwise = more resonance (smaller q)
    q_real = qmax_res + (qmin_res - qmax_res) * v01
    q_real = max(0.02, min(3.99, q_real))
    return int(round(q_real * 16384))          # Q14


def _lin(v01, lo, hi):
    return int(round(lo + (hi - lo) * v01))


# ---- pot slot assignments -------------------------------------------------
# Each entry maps a physical pot slot to a parameter and how to scale it.
# kind: "lin" (linear 16-bit), "int" (small integer), or "special" (callable).
# 'invert' flips pot direction. Slots not listed here are simply unused.
POT_MAP = {
    # ---- Mux A (ADC CH0), pots 0..7 ----
    0:  dict(param="attack",      reg="attack",      kind="lin",  lo=3,    hi=2500),
    1:  dict(param="decay",       reg="decay",       kind="lin",  lo=2,    hi=1500),
    2:  dict(param="sustain",     reg="sustain",     kind="lin",  lo=0,    hi=65535),
    3:  dict(param="release",     reg="release",     kind="lin",  lo=2,    hi=2000),
    4:  dict(param="cutoff",      reg="filter_f",    kind="special", fn="cutoff_to_f"),
    5:  dict(param="resonance",   reg="filter_q",    kind="special", fn="resonance_to_q"),
    6:  dict(param="pulse_width", reg="pulse_width", kind="lin",  lo=3000, hi=62000),
    7:  dict(param="volume",      reg="volume",      kind="lin",  lo=0,    hi=65535),
    # ---- Mux B (ADC CH1), pots 8..15 ----
    8:  dict(param="detune",      reg="detune",      kind="int",  lo=0,    hi=7),
    # 9..15 free for expansion
    # ---- Mux C (ADC CH2), pots 16..23 ----
    # 16..23 free for expansion
}

# ---- toggle / choice params: GUI-controlled, with defaults ----
TOGGLES = {
    "waveform":      dict(default=3, lo=0, hi=9),
    "voice_mask":    dict(default=0b1111111111, lo=0, hi=1023),
    "mute":          dict(default=0, lo=0, hi=1),
    "filter_bypass": dict(default=0, lo=0, hi=1),
    "osc_b":         dict(default=1, lo=0, hi=1),
    "filter_type":   dict(default=0, lo=0, hi=3),   # 0 LP 1 BP 2 HP 3 notch
}

WAVEFORM_NAMES = {0:"Saw",1:"Square",2:"Triangle",3:"Sine",4:"Organ",5:"Growl",6:"Formant",7:"Half Sine",8:"Fold",9:"Bell"}
NUM_VOICES = 10
FILTER_TYPE_NAMES = {0: "Low-pass", 1: "Band-pass", 2: "High-pass", 3: "Notch"}

_SPECIAL = {"cutoff_to_f": cutoff_to_f, "resonance_to_q": resonance_to_q}


def scale_pot(spec, adc_value):
    """Convert a raw 0..1023 ADC reading into a 16-bit register value."""
    v01 = max(0.0, min(1.0, adc_value / 1023.0))
    if spec.get("invert"):
        v01 = 1.0 - v01
    if spec["kind"] == "special":
        return _SPECIAL[spec["fn"]](v01)
    val = _lin(v01, spec["lo"], spec["hi"])
    return max(0, min(65535, val))


def active_pot_map():
    """POT_MAP entries whose ADC channel is actually populated."""
    return {slot: spec for slot, spec in POT_MAP.items()
            if (slot // 8) in ENABLED_MUX_CHANNELS}


def slot_label(slot):
    ch, idx = slot // 8, slot % 8
    return f"{MUX_REFDES.get(ch, '?')} CH{ch}.Y{idx}"


def manual_to_register(spec, slider_value):
    """Convert a MANUAL slider value (0..65535) into the register value.
    For 'special' params (cutoff, resonance) the slider is treated as a
    position and run through the same mapping the pot uses, so manual and
    pot behave identically and both stay in the filter's stable range.
    For ordinary params the slider value is used directly (already a
    register value)."""
    if spec["kind"] == "special":
        v01 = max(0.0, min(1.0, slider_value / 65535.0))
        return _SPECIAL[spec["fn"]](v01)
    return max(0, min(65535, int(slider_value)))


# ---- sequencer registers (V5) ----
SEQ_REG = {
    "run_length":   0x20,   # bit0=run, bits[4:1]=length
    "step_period":  0x21,
    "gate_length":  0x22,
    "s_attack":     0x30, "s_decay": 0x31, "s_sustain": 0x32, "s_release": 0x33,
    "s_pulse_width":0x34, "s_detune": 0x35, "s_filter_f": 0x36, "s_volume": 0x37,
    "s_waveform":   0x38, "s_mute": 0x3A, "s_filter_bypass": 0x3B, "s_osc_b": 0x3C,
    "s_filter_q":   0x3D, "s_filter_type": 0x3E,
}
SEQ_STEP_BASE = 0x10   # step i -> 0x10+i

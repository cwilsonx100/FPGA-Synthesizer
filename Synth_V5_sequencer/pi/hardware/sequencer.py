"""
Sequencer engine (Pi side): scale-constrained randomizer + tempo math.
Timing runs on the FPGA; the Pi picks the notes and computes the tempo
divider, then writes everything to the sequencer registers over SPI.
"""
import random

# base timebase on the FPGA = clk_audio / 1024 = 12.288MHz/1024 = 12000 Hz
SEQ_BASE_HZ = 12000

# scales as semitone offsets from the root
SCALES = {
    "Major":            [0, 2, 4, 5, 7, 9, 11],
    "Natural Minor":    [0, 2, 3, 5, 7, 8, 10],
    "Harmonic Minor":   [0, 2, 3, 5, 7, 8, 11],
    "Dorian":           [0, 2, 3, 5, 7, 9, 10],
    "Phrygian":         [0, 1, 3, 5, 7, 8, 10],
    "Mixolydian":       [0, 2, 4, 5, 7, 9, 10],
    "Major Pentatonic": [0, 2, 4, 7, 9],
    "Minor Pentatonic": [0, 3, 5, 7, 10],
    "Blues":            [0, 3, 5, 6, 7, 10],
    "Chromatic":        list(range(12)),
}
ROOTS = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# rhythmic divisions -> steps per beat
DIVISIONS = {
    "1/4":          1,
    "1/8":          2,
    "1/8 Triplet":  3,
    "1/16":         4,
}


def root_index(name):
    return ROOTS.index(name) if name in ROOTS else 0


def build_scale_notes(root_name, scale_name, octave_low=4, octave_high=6):
    """All MIDI notes in the chosen scale across the octave range."""
    root = root_index(root_name)
    intervals = SCALES.get(scale_name, SCALES["Major"])
    notes = []
    for octave in range(octave_low, octave_high + 1):
        base = (octave + 1) * 12 + root   # MIDI: C4 = 60
        for iv in intervals:
            n = base + iv
            if 0 <= n <= 127:
                notes.append(n)
    return sorted(set(notes))


def randomize_pattern(root_name, scale_name, length=8,
                      rest_prob=0.15, octave_low=4, octave_high=6, seed=None):
    """Generate `length` steps of {active, note}. Notes are drawn from the
    scale so they always sound consonant. Rests add rhythmic interest."""
    if seed is not None:
        random.seed(seed)
    pool = build_scale_notes(root_name, scale_name, octave_low, octave_high)
    steps = []
    for _ in range(length):
        if random.random() < rest_prob:
            steps.append({"active": False, "note": 0})
        else:
            steps.append({"active": True, "note": random.choice(pool)})
    # guarantee at least one active step
    if not any(s["active"] for s in steps):
        steps[0] = {"active": True, "note": random.choice(pool)}
    return steps


def step_register_value(step):
    """Pack a step into the 16-bit register value {active, note[6:0]}."""
    return ((1 << 7) | (step["note"] & 0x7F)) if step["active"] else 0


def tempo_to_registers(bpm, division_name, gate_fraction):
    """Compute (step_period, gate_length) in FPGA base ticks."""
    div = DIVISIONS.get(division_name, 1)          # steps per beat
    steps_per_sec = bpm / 60.0 * div
    step_period = int(round(SEQ_BASE_HZ / steps_per_sec)) if steps_per_sec > 0 else 6000
    step_period = max(1, min(65535, step_period))
    gate_length = int(round(step_period * gate_fraction))
    gate_length = max(1, min(step_period, gate_length))
    return step_period, gate_length

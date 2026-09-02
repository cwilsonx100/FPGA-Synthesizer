"""
Synth control system - Raspberry Pi 4  (V3: muxed pots + state-variable filter)

  * Scans up to 24 pots through 3x CD74HC4051 muxes (shared select lines).
  * Applies per-pot source (POT live / MANUAL from GUI).
  * Applies GUI toggles/choices (waveform, filter type, mute, bypass, osc B,
    per-voice enable).
  * Writes changed registers to the FPGA over SPI (CE1).
  * Serves a simple web GUI.

Run:            python synth_control.py    ->  http://<pi-ip>:8000
Develop off-Pi: SYNTH_FAKE=1 python synth_control.py
"""
import os
import threading
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.responses import FileResponse
from pydantic import BaseModel

from hardware.mcp3008 import MCP3008
from hardware.fpga_spi import FpgaSpi
from hardware.mux import MuxSelect
from hardware import mappings as M
from hardware.wave_paths import WAVE_PATHS
from hardware import sequencer as SEQ

HERE = os.path.dirname(os.path.abspath(__file__))
LOOP_HZ = 50


class SynthState:
    def __init__(self):
        self.lock = threading.Lock()
        # per active pot slot: source + manual register value
        self.pot_slots = dict(M.active_pot_map())
        self.source = {s: "pot" for s in self.pot_slots}
        self.manual = {s: 0 for s in self.pot_slots}
        self.adc_raw = {s: 0 for s in self.pot_slots}
        self.reg_value = {s: 0 for s in self.pot_slots}
        self.toggles = {n: sp["default"] for n, sp in M.TOGGLES.items()}
        self.loop_rate = 0.0
        self.running = True


state = SynthState()

class SeqState:
    def __init__(self):
        self.lock = threading.Lock()
        self.run = False
        self.bpm = 120
        self.division = "1/8"
        self.gate_fraction = 0.5
        self.length = 8
        self.root = "C"
        self.scale = "Minor Pentatonic"
        self.rest_prob = 0.15
        self.oct_low = 3
        self.oct_high = 5
        self.pattern = SEQ.randomize_pattern("C", "Minor Pentatonic", 8, seed=1)
        # independent sequencer bank params (register value space)
        self.bank = {
            "s_waveform": 0, "s_attack": 800, "s_decay": 120, "s_sustain": 40000,
            "s_release": 600, "s_detune": 0, "s_filter_f": 8000, "s_filter_q": 11585,
            "s_filter_type": 0, "s_volume": 32768, "s_mute": 0, "s_filter_bypass": 0,
            "s_osc_b": 1, "s_pulse_width": 32768,
        }
        self.dirty_all = True   # force a full push on start

seq = SeqState()

adc = MCP3008(bus=0, device=0)
fpga = FpgaSpi(bus=0, device=1, verbose=True)
mux = MuxSelect(s0=17, s1=27, s2=22)


def scan_and_build():
    """Scan all mux positions, build {reg_addr: value}."""
    regs = {}

    with state.lock:
        slots = dict(state.pot_slots)
        sources = dict(state.source)
        manuals = dict(state.manual)

    # scan the 8 mux indices; at each index read the 3 muxed ADC channels
    for idx in range(8):
        mux.select(idx)
        for ch in M.MUX_ADC_CHANNELS:
            slot = M.slot_to_addr(ch, idx)
            if slot not in slots:
                continue
            spec = slots[slot]
            if sources[slot] == "pot":
                raw = adc.read(ch)
                val = M.scale_pot(spec, raw)
                with state.lock:
                    state.adc_raw[slot] = raw
            else:
                val = M.manual_to_register(spec, manuals[slot])
            regs[M.REG[spec["reg"]]] = val
            with state.lock:
                state.reg_value[slot] = val

    # toggles / choices
    with state.lock:
        t = dict(state.toggles)
    regs[M.REG["waveform"]]      = int(t["waveform"]) & 0x3
    regs[M.REG["voice_mask"]]    = int(t["voice_mask"]) & 0xF
    regs[M.REG["mute"]]          = int(t["mute"]) & 0x1
    regs[M.REG["filter_bypass"]] = int(t["filter_bypass"]) & 0x1
    regs[M.REG["osc_b"]]         = int(t["osc_b"]) & 0x1
    regs[M.REG["filter_type"]]   = int(t["filter_type"]) & 0x3
    return regs




_seq_last = {}
def push_sequencer(force=False):
    """Write changed sequencer registers to the FPGA."""
    with seq.lock:
        run=seq.run; bpm=seq.bpm; div=seq.division; gate=seq.gate_fraction
        length=seq.length; pattern=list(seq.pattern); bank=dict(seq.bank)
        dirty=seq.dirty_all or force; seq.dirty_all=False
    regs = {}
    sp, gl = SEQ.tempo_to_registers(bpm, div, gate)
    regs[M.SEQ_REG["step_period"]] = sp
    regs[M.SEQ_REG["gate_length"]] = gl
    regs[M.SEQ_REG["run_length"]] = (1 if run else 0) | ((length & 0xF) << 1)
    for i, st in enumerate(pattern[:16]):
        regs[M.SEQ_STEP_BASE + i] = SEQ.step_register_value(st)
    for name, val in bank.items():
        regs[M.SEQ_REG[name]] = int(val) & 0xFFFF
    for addr, val in regs.items():
        if dirty or _seq_last.get(addr) != val:
            fpga.write_register(addr, val)
            _seq_last[addr] = val


def control_loop():
    period = 1.0 / LOOP_HZ
    last_sent = {}
    last_time = time.time()
    ewma = LOOP_HZ
    while state.running:
        start = time.time()
        regs = scan_and_build()
        for addr, val in regs.items():
            if last_sent.get(addr) != val:
                fpga.write_register(addr, val)
                last_sent[addr] = val
        push_sequencer()
        now = time.time()
        dt = now - last_time
        last_time = now
        if dt > 0:
            ewma = 0.9 * ewma + 0.1 * (1.0 / dt)
        with state.lock:
            state.loop_rate = round(ewma, 1)
        sleep = period - (time.time() - start)
        if sleep > 0:
            time.sleep(sleep)


@asynccontextmanager
async def lifespan(app: FastAPI):
    t = threading.Thread(target=control_loop, daemon=True)
    t.start()
    yield
    state.running = False
    time.sleep(0.1)
    adc.close(); fpga.close(); mux.close()


app = FastAPI(lifespan=lifespan)


class SetSource(BaseModel):
    slot: int
    source: str


class SetManual(BaseModel):
    slot: int
    value: int


class SetToggle(BaseModel):
    name: str
    value: int


@app.get("/")
def index():
    return FileResponse(os.path.join(HERE, "static", "index.html"))


@app.get("/api/state")
def get_state():
    with state.lock:
        return {
            "simulated": adc.simulated or fpga.simulated or mux.simulated,
            "loop_rate": state.loop_rate,
            "pots": {
                str(slot): {
                    "param": sp["param"],
                    "reg": sp["reg"],
                    "source": state.source[slot],
                    "manual": state.manual[slot],
                    "adc_raw": state.adc_raw[slot],
                    "value": state.reg_value[slot],
                    "adc_ch": slot // 8,
                    "mux_index": slot % 8,
                    "label": M.slot_label(slot),
                }
                for slot, sp in state.pot_slots.items()
            },
            "toggles": dict(state.toggles),
            "waveform_names": M.WAVEFORM_NAMES,
            "filter_type_names": M.FILTER_TYPE_NAMES,
            "wave_paths": WAVE_PATHS,
            "num_voices": M.NUM_VOICES,
            "enabled_mux_channels": list(M.ENABLED_MUX_CHANNELS),
            "mux_refdes": M.MUX_REFDES,
            "sequencer": seq_state_dict(),
        }


@app.post("/api/source")
def set_source(req: SetSource):
    if req.slot not in state.pot_slots or req.source not in ("pot", "manual"):
        return {"ok": False}
    with state.lock:
        state.source[req.slot] = req.source
    return {"ok": True}


@app.post("/api/manual")
def set_manual(req: SetManual):
    if req.slot not in state.pot_slots:
        return {"ok": False}
    with state.lock:
        state.manual[req.slot] = max(0, min(65535, int(req.value)))
    return {"ok": True}


@app.post("/api/toggle")
def set_toggle(req: SetToggle):
    if req.name not in M.TOGGLES:
        return {"ok": False}
    spec = M.TOGGLES[req.name]
    v = max(spec["lo"], min(spec["hi"], int(req.value)))
    with state.lock:
        state.toggles[req.name] = v
    return {"ok": True}




def seq_state_dict():
    with seq.lock:
        return {
            "run": seq.run, "bpm": seq.bpm, "division": seq.division,
            "gate_fraction": seq.gate_fraction, "length": seq.length,
            "root": seq.root, "scale": seq.scale, "rest_prob": seq.rest_prob,
            "oct_low": seq.oct_low, "oct_high": seq.oct_high,
            "pattern": seq.pattern, "bank": seq.bank,
            "scales": list(SEQ.SCALES.keys()), "roots": SEQ.ROOTS,
            "divisions": list(SEQ.DIVISIONS.keys()),
            "waveform_names": M.WAVEFORM_NAMES,
        }


class SeqSet(BaseModel):
    bpm: int | None = None
    division: str | None = None
    gate_fraction: float | None = None
    length: int | None = None
    root: str | None = None
    scale: str | None = None
    rest_prob: float | None = None
    run: bool | None = None
    oct_low: int | None = None
    oct_high: int | None = None


class SeqBankSet(BaseModel):
    name: str
    value: int


@app.get("/api/sequencer")
def get_seq():
    return seq_state_dict()


@app.post("/api/sequencer/set")
def set_seq(req: SeqSet):
    with seq.lock:
        if req.bpm is not None: seq.bpm = max(20, min(300, req.bpm))
        if req.division is not None and req.division in SEQ.DIVISIONS: seq.division = req.division
        if req.gate_fraction is not None: seq.gate_fraction = max(0.05, min(1.0, req.gate_fraction))
        if req.length is not None: seq.length = max(1, min(16, req.length))
        if req.root is not None and req.root in SEQ.ROOTS: seq.root = req.root
        if req.scale is not None and req.scale in SEQ.SCALES: seq.scale = req.scale
        if req.rest_prob is not None: seq.rest_prob = max(0.0, min(0.8, req.rest_prob))
        if req.oct_low is not None: seq.oct_low = max(1, min(7, req.oct_low))
        if req.oct_high is not None: seq.oct_high = max(1, min(7, req.oct_high))
        if seq.oct_high < seq.oct_low: seq.oct_high = seq.oct_low
        if req.run is not None: seq.run = bool(req.run)
        seq.dirty_all = True
    return {"ok": True}


@app.post("/api/sequencer/randomize")
def randomize_seq():
    with seq.lock:
        seq.pattern = SEQ.randomize_pattern(seq.root, seq.scale, seq.length,
                                            rest_prob=seq.rest_prob,
                                            octave_low=seq.oct_low, octave_high=seq.oct_high)
        seq.dirty_all = True
    return {"ok": True}


# continuous seq params -> (lo, hi) register range (mirrors the main synth pots)
SEQ_CONT = {
    "s_attack": (3, 2500), "s_decay": (2, 1500), "s_sustain": (0, 65535),
    "s_release": (2, 2000), "s_pulse_width": (3000, 62000), "s_volume": (0, 65535),
}

@app.post("/api/sequencer/bank")
def set_seq_bank(req: SeqBankSet):
    """Discrete params (waveform, filter_type, mute, filter_bypass, osc_b) take
    the value directly. Continuous params take a 0..1000 slider position and are
    scaled here with the same ranges/curves as the live synth."""
    name = req.name
    if name not in seq.bank:
        return {"ok": False}
    v = req.value
    if name in SEQ_CONT:
        lo, hi = SEQ_CONT[name]
        val = int(round(lo + (hi - lo) * (v / 1000.0)))
    elif name == "s_filter_f":
        val = M.cutoff_to_f(v / 1000.0)          # calibrated log cutoff -> Q14
    elif name == "s_filter_q":
        val = M.resonance_to_q(v / 1000.0)       # resonance -> Q14
    elif name == "s_detune":
        val = int(round(7 * v / 1000.0))
    else:
        val = int(v)                             # discrete
    with seq.lock:
        seq.bank[name] = max(0, min(65535, val))
        seq.dirty_all = True
    return {"ok": True}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

`timescale 1ns / 1ps

//==========================================================================
// Voice_core (V4)
//   Two oscillators (detune pair) sharing ONE dual-port Wavetable_rom, plus
//   an ADSR VCA. osc_b_enable collapses to a single oscillator when 0.
//==========================================================================

module Voice_core(
    input  wire        clk,
    input  wire        reset,
    input  wire        sample_tick,

    input  wire [31:0] phase_inc,
    input  wire [3:0]  waveform,
    input  wire [15:0] pulse_width,
    input  wire [2:0]  detune_level,
    input  wire        osc_b_enable,

    input  wire        gate,
    input  wire [15:0] attack_step,
    input  wire [15:0] decay_step,
    input  wire [15:0] sustain_level,
    input  wire [15:0] release_step,

    output wire signed [15:0] voice_sample
);

    wire [31:0] detune_offset =
        (detune_level == 3'd0) ? 32'd0             :
        (detune_level == 3'd1) ? (phase_inc >> 11) :
        (detune_level == 3'd2) ? (phase_inc >> 10) :
        (detune_level == 3'd3) ? (phase_inc >> 9)  :
        (detune_level == 3'd4) ? (phase_inc >> 8)  :
        (detune_level == 3'd5) ? (phase_inc >> 7)  :
                                 (phase_inc >> 6);

    wire [31:0] phase_inc_a = phase_inc - detune_offset;
    wire [31:0] phase_inc_b = phase_inc + detune_offset;

    // shared dual-port wavetable ROM
    wire [2:0] sel_a, sel_b;
    wire [7:0] ph_a, ph_b;
    wire signed [15:0] wt_a, wt_b;

    Wavetable_rom wavetables (
        .clk(clk),
        .sel_a(sel_a), .phase_a(ph_a), .sample_a(wt_a),
        .sel_b(sel_b), .phase_b(ph_b), .sample_b(wt_b)
    );

    wire signed [15:0] osc_a, osc_b;

    Osc_core oscillator_a (
        .clk(clk), .reset(reset), .sample_tick(sample_tick),
        .phase_inc(phase_inc_a), .waveform(waveform), .pulse_width(pulse_width),
        .wt_sel(sel_a), .wt_phase(ph_a), .wt_sample(wt_a),
        .sample(osc_a)
    );
    Osc_core oscillator_b (
        .clk(clk), .reset(reset), .sample_tick(sample_tick),
        .phase_inc(phase_inc_b), .waveform(waveform), .pulse_width(pulse_width),
        .wt_sel(sel_b), .wt_phase(ph_b), .wt_sample(wt_b),
        .sample(osc_b)
    );

    wire signed [15:0] osc_mix =
        osc_b_enable ? ((osc_a >>> 1) + (osc_b >>> 1)) : osc_a;

    wire [15:0] env_level;
    wire [2:0]  env_state;
    Simple_adsr envelope (
        .clk(clk), .reset(reset), .sample_tick(sample_tick), .gate(gate),
        .attack_step(attack_step), .decay_step(decay_step),
        .sustain_level(sustain_level), .release_step(release_step),
        .env_level(env_level), .env_state(env_state)
    );

    wire signed [32:0] vca = $signed(osc_mix) * $signed({1'b0, env_level});
    assign voice_sample = vca >>> 16;

endmodule

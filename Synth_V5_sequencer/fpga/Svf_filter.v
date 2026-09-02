`timescale 1ns / 1ps

//============================================================================
// Svf_filter  -  Chamberlin state-variable filter (12 dB/oct)
//
//   Produces low-pass, band-pass, high-pass and notch from one structure,
//   with a resonance control. Replaces the old 1-pole shift filter (which
//   could stall to silence). Numerically robust: state kept at Q8 precision
//   so the integrators never round a step to zero, plus saturation backstop.
//
//   Coefficients come pre-computed from the Pi (keeps the FPGA free of sin()
//   and division):
//     f = 2*sin(pi*Fc/Fs)   as Q14 unsigned  (cutoff)   0 < f < 1.0
//     q = 1/Q               as Q14 unsigned  (resonance) small q = resonant
//
//   Update (per sample_tick), classic Chamberlin order:
//     lp += f*bp;   hp = in - lp - q*bp;   bp += f*hp;   notch = hp + lp
//============================================================================

module Svf_filter(
    input  wire               clk,
    input  wire               reset,
    input  wire               sample_tick,

    input  wire signed [15:0] in_sample,
    input  wire        [15:0] f_coeff,     // Q14 cutoff  (0..~16187)
    input  wire        [15:0] q_coeff,     // Q14 damping (0..65535 = 0..4.0)
    input  wire        [1:0]  ftype,       // 0 LP, 1 BP, 2 HP, 3 notch

    output reg  signed [15:0] out_sample
);

    localparam integer QSHIFT = 14;                 // coefficient fractional bits
    localparam integer FRAC   = 8;                  // state fractional bits
    localparam signed [31:0] SAT_HI =  32'sd536870912;  // +2^29
    localparam signed [31:0] SAT_LO = -32'sd536870912;  // -2^29

    // state (Q8): lowpass and bandpass integrators
    reg signed [31:0] lp = 32'sd0;
    reg signed [31:0] bp = 32'sd0;

    // input scaled to Q8
    wire signed [31:0] in_q8 = $signed(in_sample) <<< FRAC;

    // coefficients as signed-positive
    wire signed [17:0] f_s = $signed({2'b00, f_coeff});
    wire signed [17:0] q_s = $signed({2'b00, q_coeff});

    // f*bp  (old bp) -> lp update
    wire signed [63:0] f_bp = f_s * bp;
    wire signed [31:0] f_bp_s = f_bp >>> QSHIFT;
    wire signed [31:0] lp_next_raw = lp + f_bp_s;

    // q*bp (old bp)
    wire signed [63:0] q_bp = q_s * bp;
    wire signed [31:0] q_bp_s = q_bp >>> QSHIFT;

    // hp = in - lp_next - q*bp
    wire signed [31:0] hp = in_q8 - lp_next_raw - q_bp_s;

    // f*hp -> bp update
    wire signed [63:0] f_hp = f_s * hp;
    wire signed [31:0] f_hp_s = f_hp >>> QSHIFT;
    wire signed [31:0] bp_next_raw = bp + f_hp_s;

    // notch = hp + lp
    wire signed [31:0] notch = hp + lp_next_raw;

    // saturate helper via functions
    function signed [31:0] sat32(input signed [31:0] v);
        if (v > SAT_HI)      sat32 = SAT_HI;
        else if (v < SAT_LO) sat32 = SAT_LO;
        else                 sat32 = v;
    endfunction

    wire signed [31:0] lp_next = sat32(lp_next_raw);
    wire signed [31:0] bp_next = sat32(bp_next_raw);

    // choose output (Q8), then back to 16-bit with saturation
    reg signed [31:0] sel;
    always @(*) begin
        case (ftype)
            2'd0:    sel = lp_next;
            2'd1:    sel = bp_next;
            2'd2:    sel = hp;
            default: sel = notch;
        endcase
    end

    wire signed [31:0] out_full = sel >>> FRAC;

    always @(posedge clk) begin
        if (reset) begin
            lp <= 32'sd0;
            bp <= 32'sd0;
            out_sample <= 16'sd0;
        end else if (sample_tick) begin
            lp <= lp_next;
            bp <= bp_next;
            if      (out_full >  32'sd32767) out_sample <=  16'sd32767;
            else if (out_full < -32'sd32768) out_sample <= -16'sd32768;
            else                             out_sample <=  out_full[15:0];
        end
    end

endmodule

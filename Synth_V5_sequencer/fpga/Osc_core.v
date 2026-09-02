`timescale 1ns / 1ps

//==========================================================================
// Osc_core (V4)
//   saw/square/triangle generated algorithmically; sine + 6 wavetables read
//   from a shared dual-port Wavetable_rom (instantiated in Voice_core). The
//   oscillator drives a ROM read port (wt_sel/wt_phase) and receives wt_sample
//   back one clock later; since phase is stable between sample_ticks, the
//   BRAM latency is hidden.
//
//   waveform: 0 saw, 1 square, 2 triangle, 3 sine, 4 organ, 5 soft-square,
//             6 formant, 7 half-sine, 8 acid, 9 bell
//==========================================================================

module Osc_core(
    input  wire               clk,
    input  wire               reset,
    input  wire               sample_tick,
    input  wire [31:0]        phase_inc,
    input  wire [3:0]         waveform,       // widened 2->4 bits
    input  wire [15:0]        pulse_width,

    // shared wavetable ROM read port
    output wire [2:0]         wt_sel,
    output wire [7:0]         wt_phase,
    input  wire signed [15:0] wt_sample,

    output reg  signed [15:0] sample
);

    reg  [31:0] phase = 32'd0;
    wire [31:0] phase_next = phase + phase_inc;
    wire [15:0] phase16 = phase[31:16];

    // ---- algorithmic waves (from current phase) ----
    wire signed [15:0] saw_sample = $signed(phase16 ^ 16'h8000);

    localparam signed [15:0] AMP = 16'sd24000;
    wire signed [15:0] square_sample = (phase16 < pulse_width) ? AMP : -AMP;

    wire [15:0] folded = phase16[15] ? ~phase16 : phase16;
    wire signed [15:0] tri_sample = $signed({folded[14:0],1'b0} ^ 16'h8000);

    // ---- wavetable read port (waveform>=3 selects table waveform-3) ----
    assign wt_phase = phase[31:24];
    assign wt_sel   = (waveform >= 4'd3) ? (waveform - 4'd3) : 3'd0;

    always @(posedge clk) begin
        if (reset) begin
            phase  <= 32'd0;
            sample <= 16'sd0;
        end else if (sample_tick) begin
            phase <= phase_next;
            case (waveform)
                4'd0: sample <= saw_sample;
                4'd1: sample <= square_sample;
                4'd2: sample <= tri_sample;
                default: sample <= wt_sample;   // 3..9 wavetable
            endcase
        end
    end

endmodule

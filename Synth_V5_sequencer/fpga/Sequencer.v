`timescale 1ns / 1ps

//==========================================================================
// Sequencer  -  FPGA-timed mono step sequencer (2-voice ping-pong output)
//   Timebase: clk_audio / PRESCALE  (12.288 MHz / 1024 = 12 kHz).
//   The Pi loads: step_period (base ticks/step), gate_length (base ticks the
//   note is held), length (# active steps), run, and 16 step-notes.
//   Each step-note is {active, note[6:0]}: active=0 is a rest.
//   New notes alternate between the two output voices so releases overlap.
//==========================================================================

module Sequencer #(
    parameter integer PRESCALE = 1024
)(
    input  wire        clk,
    input  wire        reset,

    input  wire        run,
    input  wire [3:0]  length,        // number of steps (1..16)
    input  wire [15:0] step_period,   // base ticks per step
    input  wire [15:0] gate_length,   // base ticks note held on
    input  wire [127:0] steps,        // 16 x {active, note[6:0]}

    output reg  [6:0]  note_a,
    output reg         gate_a,
    output reg  [6:0]  note_b,
    output reg         gate_b,
    output reg  [3:0]  cur_step        // for GUI/debug
);

    reg [15:0] pre_cnt      = 16'd0;
    reg [15:0] tick_in_step = 16'd0;
    reg        started      = 1'b0;
    reg        target       = 1'b0;    // ping-pong voice select

    wire base_tick = (pre_cnt == PRESCALE-1);

    // next step index (wrap at length)
    wire [3:0] next_step = (cur_step >= (length - 4'd1)) ? 4'd0 : (cur_step + 4'd1);

    // helper: fields of an arbitrary step
    wire [7:0] this_field = steps[cur_step*8 +: 8];
    wire [7:0] next_field = steps[next_step*8 +: 8];

    always @(posedge clk) begin
        if (reset) begin
            pre_cnt<=0; tick_in_step<=0; started<=0; target<=0;
            cur_step<=0; note_a<=0; gate_a<=0; note_b<=0; gate_b<=0;
        end else if (!run) begin
            // stop: silence and rewind to step 0
            pre_cnt<=0; tick_in_step<=0; started<=0; target<=0;
            cur_step<=0; gate_a<=0; gate_b<=0;
        end else begin
            // prescaler
            if (base_tick) pre_cnt<=0; else pre_cnt<=pre_cnt+1'b1;

            if (base_tick) begin
                if (!started) begin
                    // fire the very first step
                    started<=1; tick_in_step<=0;
                    if (this_field[7]) begin
                        target<=1'b1;
                        note_b<=this_field[6:0]; gate_b<=1'b1; gate_a<=1'b0;
                    end else begin
                        gate_a<=1'b0; gate_b<=1'b0;
                    end
                end else if (tick_in_step >= (step_period - 16'd1)) begin
                    // step boundary: advance and trigger next step
                    tick_in_step<=0;
                    cur_step<=next_step;
                    if (next_field[7]) begin
                        target<=~target;
                        if (~target) begin  // will become b
                            note_b<=next_field[6:0]; gate_b<=1'b1; gate_a<=1'b0;
                        end else begin
                            note_a<=next_field[6:0]; gate_a<=1'b1; gate_b<=1'b0;
                        end
                    end else begin
                        gate_a<=1'b0; gate_b<=1'b0;  // rest
                    end
                end else begin
                    tick_in_step<=tick_in_step+1'b1;
                    // note-off at gate_length (release; next step retriggers)
                    if ((tick_in_step + 16'd1) == gate_length) begin
                        gate_a<=1'b0; gate_b<=1'b0;
                    end
                end
            end
        end
    end

endmodule

`timescale 1ns / 1ps

//==========================================================================
// Param_regfile (V5)  - main synth bank + sequencer engine + sequencer bank
//
//  MAIN BANK (live MIDI, 10 voices)          SEQUENCER ENGINE
//   0x00 attack      0x08 waveform[3:0]        0x10..0x1F step notes {act,note[6:0]}
//   0x01 decay       0x09 voice_mask[9:0]      0x20 seq_run(bit0)+length(bits4:1)
//   0x02 sustain     0x0A mute                 0x21 seq_step_period[15:0]
//   0x03 release     0x0B filter_bypass        0x22 seq_gate_length[15:0]
//   0x04 pulse_width 0x0C osc_b
//   0x05 detune[2:0] 0x0D filter_q            SEQUENCER BANK (2 voices, independent)
//   0x06 filter_f    0x0E filter_type          0x30 s_attack  0x36 s_filter_f
//   0x07 volume                                0x31 s_decay   0x37 s_volume
//                                              0x32 s_sustain 0x38 s_waveform[3:0]
//                                              0x33 s_release 0x3A s_mute
//                                              0x34 s_pulse   0x3B s_filter_bypass
//                                              0x35 s_detune  0x3C s_osc_b
//                                              0x3D s_filter_q 0x3E s_filter_type
//==========================================================================

module Param_regfile(
    input  wire        clk,
    input  wire        reset,
    input  wire        wr_en,
    input  wire [7:0]  wr_addr,
    input  wire [15:0] wr_data,

    // ---- main bank ----
    output reg  [15:0] attack_step, decay_step, sustain_level, release_step, pulse_width,
    output reg  [2:0]  detune_level,
    output reg  [15:0] filter_f, master_volume,
    output reg  [3:0]  waveform_select,
    output reg  [9:0]  voice_enable_mask,
    output reg         master_mute, filter_bypass, osc_b_enable,
    output reg  [15:0] filter_q,
    output reg  [1:0]  filter_type,

    // ---- sequencer engine ----
    output reg         seq_run,
    output reg  [3:0]  seq_length,
    output reg  [15:0] seq_step_period,
    output reg  [15:0] seq_gate_length,
    output reg  [127:0] seq_steps,

    // ---- sequencer bank ----
    output reg  [15:0] s_attack, s_decay, s_sustain, s_release, s_pulse_width,
    output reg  [2:0]  s_detune,
    output reg  [15:0] s_filter_f, s_volume,
    output reg  [3:0]  s_waveform,
    output reg         s_mute, s_filter_bypass, s_osc_b,
    output reg  [15:0] s_filter_q,
    output reg  [1:0]  s_filter_type
);

    integer j;
    always @(posedge clk) begin
        if (reset) begin
            attack_step<=1200; decay_step<=80; sustain_level<=48000; release_step<=400;
            pulse_width<=32768; detune_level<=0; filter_f<=6000; master_volume<=32768;
            waveform_select<=3; voice_enable_mask<=10'h3FF; master_mute<=0;
            filter_bypass<=0; osc_b_enable<=1; filter_q<=11585; filter_type<=0;

            seq_run<=0; seq_length<=8; seq_step_period<=6000; seq_gate_length<=3000;
            seq_steps<=128'd0;

            s_attack<=800; s_decay<=120; s_sustain<=40000; s_release<=600;
            s_pulse_width<=32768; s_detune<=0; s_filter_f<=8000; s_volume<=32768;
            s_waveform<=0; s_mute<=0; s_filter_bypass<=0; s_osc_b<=1;
            s_filter_q<=11585; s_filter_type<=0;
        end else if (wr_en) begin
            // step notes 0x10..0x1F
            if (wr_addr >= 8'h10 && wr_addr <= 8'h1F) begin
                seq_steps[(wr_addr - 8'h10)*8 +: 8] <= wr_data[7:0];
            end else begin
                case (wr_addr)
                    // main bank
                    8'h00: attack_step<=wr_data;     8'h01: decay_step<=wr_data;
                    8'h02: sustain_level<=wr_data;   8'h03: release_step<=wr_data;
                    8'h04: pulse_width<=wr_data;     8'h05: detune_level<=wr_data[2:0];
                    8'h06: filter_f<=wr_data;        8'h07: master_volume<=wr_data;
                    8'h08: waveform_select<=wr_data[3:0]; 8'h09: voice_enable_mask<=wr_data[9:0];
                    8'h0A: master_mute<=wr_data[0];  8'h0B: filter_bypass<=wr_data[0];
                    8'h0C: osc_b_enable<=wr_data[0]; 8'h0D: filter_q<=wr_data;
                    8'h0E: filter_type<=wr_data[1:0];
                    // sequencer engine
                    8'h20: begin seq_run<=wr_data[0]; seq_length<=wr_data[4:1]; end
                    8'h21: seq_step_period<=wr_data;
                    8'h22: seq_gate_length<=wr_data;
                    // sequencer bank
                    8'h30: s_attack<=wr_data;        8'h31: s_decay<=wr_data;
                    8'h32: s_sustain<=wr_data;       8'h33: s_release<=wr_data;
                    8'h34: s_pulse_width<=wr_data;   8'h35: s_detune<=wr_data[2:0];
                    8'h36: s_filter_f<=wr_data;      8'h37: s_volume<=wr_data;
                    8'h38: s_waveform<=wr_data[3:0];
                    8'h3A: s_mute<=wr_data[0];       8'h3B: s_filter_bypass<=wr_data[0];
                    8'h3C: s_osc_b<=wr_data[0];      8'h3D: s_filter_q<=wr_data;
                    8'h3E: s_filter_type<=wr_data[1:0];
                    default: ;
                endcase
            end
        end
    end

endmodule

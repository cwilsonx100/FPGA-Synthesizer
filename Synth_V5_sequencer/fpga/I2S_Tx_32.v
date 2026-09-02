`timescale 1ns / 1ps

//============================================================================
// I2S_Tx_32
//   64-BCLK frame (32 bits/channel), 16-bit sample in the MSBs of each half.
//   This is the transmitter used by the synth. sample_tick pulses once per
//   stereo frame and drives the rest of the audio datapath.
//============================================================================

module I2S_Tx_32(
    input  wire               clk,
    input  wire               reset,

    input  wire signed [15:0] left_sample,
    input  wire signed [15:0] right_sample,

    output reg                bclk,
    output reg                lrclk,
    output reg                sdin,

    output reg                sample_tick
);

    localparam integer BCLK_DIV = 2;

    reg [1:0] div_count = 0;
    reg [5:0] bit_count = 0;

    reg signed [15:0] left_latched  = 16'sd0;
    reg signed [15:0] right_latched = 16'sd0;

    always @(posedge clk) begin
        sample_tick <= 1'b0;

        if (reset) begin
            div_count     <= 0;
            bclk          <= 0;
            lrclk         <= 0;
            sdin          <= 0;
            bit_count     <= 0;
            left_latched  <= 16'sd0;
            right_latched <= 16'sd0;
        end else begin
            if (div_count == BCLK_DIV - 1) begin
                div_count <= 0;
                bclk      <= ~bclk;

                if (bclk == 1'b1) begin
                    if (bit_count == 6'd63) begin
                        bit_count <= 6'd0;
                        lrclk     <= 1'b0;
                        sdin      <= 1'b0;

                        left_latched  <= left_sample;
                        right_latched <= right_sample;
                        sample_tick   <= 1'b1;
                    end else begin
                        bit_count <= bit_count + 1;

                        if (bit_count + 1 < 32)
                            lrclk <= 1'b0;
                        else
                            lrclk <= 1'b1;

                        if ((bit_count + 1 >= 1) && (bit_count + 1 <= 16))
                            sdin <= left_latched[16 - (bit_count + 1)];
                        else if ((bit_count + 1 >= 33) && (bit_count + 1 <= 48))
                            sdin <= right_latched[48 - (bit_count + 1)];
                        else
                            sdin <= 1'b0;
                    end
                end
            end else begin
                div_count <= div_count + 1;
            end
        end
    end

endmodule

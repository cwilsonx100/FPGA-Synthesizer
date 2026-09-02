`timescale 1ns / 1ps

//============================================================================
// Spi_slave
//   SPI slave receiver (Mode 0), Raspberry Pi is master.
//   Oversamples SCLK/MOSI/CS in the fast clk_audio domain (no separate clock
//   domain, no timing headaches). Each transaction is a 3-byte frame:
//       byte0 = register address
//       byte1 = value high byte
//       byte2 = value low byte
//   CS (active low) frames the transfer. On CS rising with >=24 bits shifted,
//   wr_en pulses for one clk_audio cycle with wr_addr / wr_data valid.
//
//   Keep the Pi SCLK well below clk_audio (e.g. 1 MHz vs 12.288 MHz).
//============================================================================

module Spi_slave(
    input  wire        clk,          // clk_audio (12.288 MHz)
    input  wire        reset,

    input  wire        spi_sclk,
    input  wire        spi_mosi,
    input  wire        spi_cs_n,

    output reg  [7:0]  wr_addr,
    output reg  [15:0] wr_data,
    output reg         wr_en
);

    // ---- 2-FF synchronizers into clk domain ----
    (* ASYNC_REG = "TRUE" *) reg sclk_s0 = 1'b0, sclk_s1 = 1'b0, sclk_s2 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg mosi_s0 = 1'b0, mosi_s1 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg cs_s0   = 1'b1, cs_s1   = 1'b1, cs_s2   = 1'b1;

    always @(posedge clk) begin
        sclk_s0 <= spi_sclk; sclk_s1 <= sclk_s0; sclk_s2 <= sclk_s1;
        mosi_s0 <= spi_mosi; mosi_s1 <= mosi_s0;
        cs_s0   <= spi_cs_n; cs_s1   <= cs_s0;   cs_s2   <= cs_s1;
    end

    wire sclk_rising = (sclk_s1 == 1'b1) && (sclk_s2 == 1'b0);
    wire cs_active   = (cs_s1 == 1'b0);
    wire cs_rising   = (cs_s1 == 1'b1) && (cs_s2 == 1'b0);  // end of frame

    reg [23:0] shifter   = 24'd0;
    reg [5:0]  bit_count = 6'd0;

    always @(posedge clk) begin
        if (reset) begin
            shifter   <= 24'd0;
            bit_count <= 6'd0;
            wr_addr   <= 8'd0;
            wr_data   <= 16'd0;
            wr_en     <= 1'b0;
        end else begin
            wr_en <= 1'b0;  // default: strobe is one cycle

            if (!cs_active) begin
                // idle between frames; bit_count re-armed by cs_active branch
                bit_count <= 6'd0;
            end else if (sclk_rising) begin
                shifter   <= {shifter[22:0], mosi_s1};
                if (bit_count != 6'd63)
                    bit_count <= bit_count + 1'b1;
            end

            // End of frame: latch a complete 24-bit write
            if (cs_rising && (bit_count >= 6'd24)) begin
                wr_addr <= shifter[23:16];
                wr_data <= shifter[15:0];
                wr_en   <= 1'b1;
            end
        end
    end

endmodule

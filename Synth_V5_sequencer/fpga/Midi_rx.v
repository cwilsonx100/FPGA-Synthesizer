`timescale 1ns / 1ps

module Midi_rx #(
    parameter CLKS_PER_BIT = 393        // 12.288 MHz / 31250 baud
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,

    output reg  [7:0] midi_byte,
    output reg        midi_valid
);

    localparam STATE_IDLE  = 3'd0;
    localparam STATE_START = 3'd1;
    localparam STATE_DATA  = 3'd2;
    localparam STATE_STOP  = 3'd3;

    (* ASYNC_REG="TRUE" *) reg rx_sync_0 = 1'b1;
    (* ASYNC_REG="TRUE" *) reg rx_sync_1 = 1'b1;
    (* ASYNC_REG="TRUE" *) reg rx_sync_2 = 1'b1;

    reg [2:0]  state     = STATE_IDLE;
    reg [15:0] clk_count = 16'd0;
    reg [2:0]  bit_index = 3'd0;
    reg [7:0]  rx_shift  = 8'd0;

    wire rx_safe = rx_sync_2;

    always @(posedge clk) begin
        rx_sync_0 <= rx;
        rx_sync_1 <= rx_sync_0;
        rx_sync_2 <= rx_sync_1;
    end

    always @(posedge clk) begin
        if (reset) begin
            state      <= STATE_IDLE;
            clk_count  <= 16'd0;
            bit_index  <= 3'd0;
            rx_shift   <= 8'd0;
            midi_byte  <= 8'd0;
            midi_valid <= 1'b0;
        end else begin
            midi_valid <= 1'b0;

            case (state)

                STATE_IDLE: begin
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (rx_safe == 1'b0)
                        state <= STATE_START;
                end

                STATE_START: begin
                    if (clk_count == (CLKS_PER_BIT / 2)) begin
                        if (rx_safe == 1'b0) begin
                            clk_count <= 16'd0;
                            state     <= STATE_DATA;
                        end else begin
                            state <= STATE_IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STATE_DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count           <= 16'd0;
                        rx_shift[bit_index] <= rx_safe;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= STATE_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STATE_STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;

                        if (rx_safe == 1'b1) begin
                            midi_byte  <= rx_shift;
                            midi_valid <= 1'b1;
                        end

                        state <= STATE_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: state <= STATE_IDLE;

            endcase
        end
    end

endmodule

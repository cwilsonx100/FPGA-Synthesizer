`timescale 1ns / 1ps

module Reset_sync(
    input  wire clk,
    input  wire pll_locked,
    output wire reset
);

    reg [15:0] reset_count = 16'd0;
    reg        reset_reg   = 1'b1;

    always @(posedge clk or negedge pll_locked) begin
        if (!pll_locked) begin
            reset_count <= 16'd0;
            reset_reg   <= 1'b1;
        end else begin
            if (reset_count != 16'hFFFF) begin
                reset_count <= reset_count + 1;
                reset_reg   <= 1'b1;
            end else begin
                reset_reg   <= 1'b0;
            end
        end
    end

    assign reset = reset_reg;

endmodule

`timescale 1ns / 1ps

module Simple_adsr(
    input  wire        clk,
    input  wire        reset,
    input  wire        sample_tick,
    input  wire        gate,
    input  wire [15:0] attack_step,
    input  wire [15:0] decay_step,
    input  wire [15:0] sustain_level,
    input  wire [15:0] release_step,
    output reg  [15:0] env_level,
    output reg  [2:0]  env_state
);

    localparam [2:0] ENV_IDLE    = 3'd0;
    localparam [2:0] ENV_ATTACK  = 3'd1;
    localparam [2:0] ENV_DECAY   = 3'd2;
    localparam [2:0] ENV_SUSTAIN = 3'd3;
    localparam [2:0] ENV_RELEASE = 3'd4;

    always @(posedge clk) begin
        if (reset) begin
            env_level <= 16'd0;
            env_state <= ENV_IDLE;
        end else if (sample_tick) begin
            case (env_state)

                ENV_IDLE: begin
                    env_level <= 16'd0;
                    if (gate) env_state <= ENV_ATTACK;
                end

                ENV_ATTACK: begin
                    if (!gate) begin
                        env_state <= ENV_RELEASE;
                    end else if (env_level >= 16'hFFFF - attack_step) begin
                        env_level <= 16'hFFFF;
                        env_state <= ENV_DECAY;
                    end else begin
                        env_level <= env_level + attack_step;
                    end
                end

                ENV_DECAY: begin
                    if (!gate) begin
                        env_state <= ENV_RELEASE;
                    end else if (env_level <= sustain_level) begin
                        env_level <= sustain_level;
                        env_state <= ENV_SUSTAIN;
                    end else if ((env_level - sustain_level) <= decay_step) begin
                        env_level <= sustain_level;
                        env_state <= ENV_SUSTAIN;
                    end else begin
                        env_level <= env_level - decay_step;
                    end
                end

                ENV_SUSTAIN: begin
                    env_level <= sustain_level;
                    if (!gate) env_state <= ENV_RELEASE;
                end

                ENV_RELEASE: begin
                    if (gate) begin
                        env_state <= ENV_ATTACK;
                    end else if (env_level <= release_step) begin
                        env_level <= 16'd0;
                        env_state <= ENV_IDLE;
                    end else begin
                        env_level <= env_level - release_step;
                    end
                end

                default: begin
                    env_level <= 16'd0;
                    env_state <= ENV_IDLE;
                end

            endcase
        end
    end

endmodule

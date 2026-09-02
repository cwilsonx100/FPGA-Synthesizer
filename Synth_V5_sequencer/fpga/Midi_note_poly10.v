`timescale 1ns / 1ps

//==========================================================================
// Midi_note_poly10  -  10-voice MIDI note allocator with voice stealing.
//   Outputs packed note/gate vectors (10 x 7-bit notes, 10 gates).
//==========================================================================

module Midi_note_poly10(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  midi_byte,
    input  wire        midi_byte_valid,

    output reg  [69:0] notes,   // 10 x 7-bit, voice i = notes[i*7 +: 7]
    output reg  [9:0]  gates
);

    reg [7:0] status;
    reg [1:0] data_count;
    reg [6:0] pending_note;
    reg [3:0] steal_ptr;        // round-robin steal pointer (0..9)

    integer v;
    reg found;

    // helpers to read/write a packed note slot
    function [6:0] get_note(input [69:0] n, input [3:0] idx);
        get_note = n[idx*7 +: 7];
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            status       <= 8'd0;
            data_count   <= 2'd0;
            pending_note <= 7'd60;
            steal_ptr    <= 4'd0;
            notes        <= {10{7'd60}};
            gates        <= 10'd0;
        end else if (midi_byte_valid) begin
            if (midi_byte >= 8'hF8) begin
                // system real-time: ignore
                status <= status; data_count <= data_count;
            end else if (midi_byte[7]) begin
                status     <= midi_byte;
                data_count <= 2'd0;
            end else begin
                case (status[7:4])
                    4'h8: begin // Note Off
                        if (data_count == 2'd0) begin
                            pending_note <= midi_byte[6:0];
                            data_count   <= 2'd1;
                        end else begin
                            for (v = 0; v < 10; v = v + 1)
                                if (gates[v] && notes[v*7 +: 7] == pending_note)
                                    gates[v] <= 1'b0;
                            data_count <= 2'd0;
                        end
                    end
                    4'h9: begin // Note On (vel 0 = off)
                        if (data_count == 2'd0) begin
                            pending_note <= midi_byte[6:0];
                            data_count   <= 2'd1;
                        end else begin
                            if (midi_byte[6:0] == 7'd0) begin
                                for (v = 0; v < 10; v = v + 1)
                                    if (gates[v] && notes[v*7 +: 7] == pending_note)
                                        gates[v] <= 1'b0;
                            end else begin
                                found = 1'b0;
                                for (v = 0; v < 10; v = v + 1) begin
                                    if (!found && !gates[v]) begin
                                        notes[v*7 +: 7] <= pending_note;
                                        gates[v]        <= 1'b1;
                                        found            = 1'b1;
                                    end
                                end
                                if (!found) begin
                                    // steal round-robin
                                    notes[steal_ptr*7 +: 7] <= pending_note;
                                    gates[steal_ptr]        <= 1'b1;
                                    steal_ptr <= (steal_ptr == 4'd9) ? 4'd0 : steal_ptr + 4'd1;
                                end
                            end
                            data_count <= 2'd0;
                        end
                    end
                    default: data_count <= 2'd0;
                endcase
            end
        end
    end

endmodule

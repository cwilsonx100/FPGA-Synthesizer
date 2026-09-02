`timescale 1ns / 1ps

//============================================================================
// Note_to_phase
//   MIDI note number -> 32-bit phase increment for the NCO.
//   Computed for Fs = 48000 Hz (clk_audio 12.288 MHz / 256), A4 = 440.000 Hz.
//   phase_inc = round( freq * 2^32 / Fs )
//============================================================================

module Note_to_phase(
    input  wire [6:0]  midi_note,
    output reg  [31:0] phase_inc
);

    always @(*) begin
        case (midi_note)

            7'd0:   phase_inc = 32'd731558;     // C-1   8.176 Hz
            7'd1:   phase_inc = 32'd775059;     // C#-1  8.662 Hz
            7'd2:   phase_inc = 32'd821146;     // D-1   9.177 Hz
            7'd3:   phase_inc = 32'd869974;     // D#-1  9.723 Hz
            7'd4:   phase_inc = 32'd921705;     // E-1   10.301 Hz
            7'd5:   phase_inc = 32'd976513;     // F-1   10.913 Hz
            7'd6:   phase_inc = 32'd1034579;    // F#-1  11.562 Hz
            7'd7:   phase_inc = 32'd1096099;    // G-1   12.250 Hz
            7'd8:   phase_inc = 32'd1161276;    // G#-1  12.978 Hz
            7'd9:   phase_inc = 32'd1230329;    // A-1   13.750 Hz
            7'd10:  phase_inc = 32'd1303488;    // A#-1  14.568 Hz
            7'd11:  phase_inc = 32'd1380998;    // B-1   15.434 Hz

            7'd12:  phase_inc = 32'd1463116;    // C0    16.352 Hz
            7'd13:  phase_inc = 32'd1550118;    // C#0   17.324 Hz
            7'd14:  phase_inc = 32'd1642292;    // D0    18.354 Hz
            7'd15:  phase_inc = 32'd1739948;    // D#0   19.445 Hz
            7'd16:  phase_inc = 32'd1843411;    // E0    20.602 Hz
            7'd17:  phase_inc = 32'd1953026;    // F0    21.827 Hz
            7'd18:  phase_inc = 32'd2069159;    // F#0   23.125 Hz
            7'd19:  phase_inc = 32'd2192197;    // G0    24.500 Hz
            7'd20:  phase_inc = 32'd2322552;    // G#0   25.957 Hz
            7'd21:  phase_inc = 32'd2460658;    // A0    27.500 Hz
            7'd22:  phase_inc = 32'd2606977;    // A#0   29.135 Hz
            7'd23:  phase_inc = 32'd2761996;    // B0    30.868 Hz

            7'd24:  phase_inc = 32'd2926232;    // C1    32.703 Hz
            7'd25:  phase_inc = 32'd3100235;    // C#1   34.648 Hz
            7'd26:  phase_inc = 32'd3284585;    // D1    36.708 Hz
            7'd27:  phase_inc = 32'd3479896;    // D#1   38.891 Hz
            7'd28:  phase_inc = 32'd3686822;    // E1    41.203 Hz
            7'd29:  phase_inc = 32'd3906052;    // F1    43.654 Hz
            7'd30:  phase_inc = 32'd4138318;    // F#1   46.249 Hz
            7'd31:  phase_inc = 32'd4384395;    // G1    48.999 Hz
            7'd32:  phase_inc = 32'd4645104;    // G#1   51.913 Hz
            7'd33:  phase_inc = 32'd4921317;    // A1    55.000 Hz
            7'd34:  phase_inc = 32'd5213953;    // A#1   58.270 Hz
            7'd35:  phase_inc = 32'd5523991;    // B1    61.735 Hz

            7'd36:  phase_inc = 32'd5852465;    // C2    65.406 Hz
            7'd37:  phase_inc = 32'd6200470;    // C#2   69.296 Hz
            7'd38:  phase_inc = 32'd6569170;    // D2    73.416 Hz
            7'd39:  phase_inc = 32'd6959793;    // D#2   77.782 Hz
            7'd40:  phase_inc = 32'd7373644;    // E2    82.407 Hz
            7'd41:  phase_inc = 32'd7812103;    // F2    87.307 Hz
            7'd42:  phase_inc = 32'd8276635;    // F#2   92.499 Hz
            7'd43:  phase_inc = 32'd8768789;    // G2    97.999 Hz
            7'd44:  phase_inc = 32'd9290209;    // G#2   103.826 Hz
            7'd45:  phase_inc = 32'd9842633;    // A2    110.000 Hz
            7'd46:  phase_inc = 32'd10427907;   // A#2   116.541 Hz
            7'd47:  phase_inc = 32'd11047982;   // B2    123.471 Hz

            7'd48:  phase_inc = 32'd11704930;   // C3    130.813 Hz
            7'd49:  phase_inc = 32'd12400941;   // C#3   138.591 Hz
            7'd50:  phase_inc = 32'd13138339;   // D3    146.832 Hz
            7'd51:  phase_inc = 32'd13919586;   // D#3   155.563 Hz
            7'd52:  phase_inc = 32'd14747287;   // E3    164.814 Hz
            7'd53:  phase_inc = 32'd15624207;   // F3    174.614 Hz
            7'd54:  phase_inc = 32'd16553270;   // F#3   184.997 Hz
            7'd55:  phase_inc = 32'd17537579;   // G3    195.998 Hz
            7'd56:  phase_inc = 32'd18580418;   // G#3   207.652 Hz
            7'd57:  phase_inc = 32'd19685267;   // A3    220.000 Hz
            7'd58:  phase_inc = 32'd20855814;   // A#3   233.082 Hz
            7'd59:  phase_inc = 32'd22095965;   // B3    246.942 Hz

            7'd60:  phase_inc = 32'd23409859;   // C4    261.626 Hz
            7'd61:  phase_inc = 32'd24801882;   // C#4   277.183 Hz
            7'd62:  phase_inc = 32'd26276679;   // D4    293.665 Hz
            7'd63:  phase_inc = 32'd27839171;   // D#4   311.127 Hz
            7'd64:  phase_inc = 32'd29494575;   // E4    329.628 Hz
            7'd65:  phase_inc = 32'd31248413;   // F4    349.228 Hz
            7'd66:  phase_inc = 32'd33106541;   // F#4   369.994 Hz
            7'd67:  phase_inc = 32'd35075158;   // G4    391.995 Hz
            7'd68:  phase_inc = 32'd37160835;   // G#4   415.305 Hz
            7'd69:  phase_inc = 32'd39370534;   // A4    440.000 Hz
            7'd70:  phase_inc = 32'd41711627;   // A#4   466.164 Hz
            7'd71:  phase_inc = 32'd44191930;   // B4    493.883 Hz

            7'd72:  phase_inc = 32'd46819719;   // C5    523.251 Hz
            7'd73:  phase_inc = 32'd49603764;   // C#5   554.365 Hz
            7'd74:  phase_inc = 32'd52553357;   // D5    587.330 Hz
            7'd75:  phase_inc = 32'd55678342;   // D#5   622.254 Hz
            7'd76:  phase_inc = 32'd58989149;   // E5    659.255 Hz
            7'd77:  phase_inc = 32'd62496826;   // F5    698.456 Hz
            7'd78:  phase_inc = 32'd66213081;   // F#5   739.989 Hz
            7'd79:  phase_inc = 32'd70150316;   // G5    783.991 Hz
            7'd80:  phase_inc = 32'd74321671;   // G#5   830.609 Hz
            7'd81:  phase_inc = 32'd78741067;   // A5    880.000 Hz
            7'd82:  phase_inc = 32'd83423255;   // A#5   932.328 Hz
            7'd83:  phase_inc = 32'd88383859;   // B5    987.767 Hz

            7'd84:  phase_inc = 32'd93639437;   // C6    1046.502 Hz
            7'd85:  phase_inc = 32'd99207528;   // C#6   1108.731 Hz
            7'd86:  phase_inc = 32'd105106715;  // D6    1174.659 Hz
            7'd87:  phase_inc = 32'd111356685;  // D#6   1244.508 Hz
            7'd88:  phase_inc = 32'd117978298;  // E6    1318.510 Hz
            7'd89:  phase_inc = 32'd124993653;  // F6    1396.913 Hz
            7'd90:  phase_inc = 32'd132426162;  // F#6   1479.978 Hz
            7'd91:  phase_inc = 32'd140300631;  // G6    1567.982 Hz
            7'd92:  phase_inc = 32'd148643341;  // G#6   1661.219 Hz
            7'd93:  phase_inc = 32'd157482134;  // A6    1760.000 Hz
            7'd94:  phase_inc = 32'd166846509;  // A#6   1864.655 Hz
            7'd95:  phase_inc = 32'd176767719;  // B6    1975.533 Hz

            7'd96:  phase_inc = 32'd187278874;  // C7    2093.005 Hz
            7'd97:  phase_inc = 32'd198415056;  // C#7   2217.461 Hz
            7'd98:  phase_inc = 32'd210213429;  // D7    2349.318 Hz
            7'd99:  phase_inc = 32'd222713370;  // D#7   2489.016 Hz
            7'd100: phase_inc = 32'd235956596;  // E7    2637.020 Hz
            7'd101: phase_inc = 32'd249987305;  // F7    2793.826 Hz
            7'd102: phase_inc = 32'd264852324;  // F#7   2959.955 Hz
            7'd103: phase_inc = 32'd280601263;  // G7    3135.963 Hz
            7'd104: phase_inc = 32'd297286682;  // G#7   3322.438 Hz
            7'd105: phase_inc = 32'd314964268;  // A7    3520.000 Hz
            7'd106: phase_inc = 32'd333693018;  // A#7   3729.310 Hz
            7'd107: phase_inc = 32'd353535438;  // B7    3951.066 Hz

            7'd108: phase_inc = 32'd374557749;  // C8    4186.009 Hz
            7'd109: phase_inc = 32'd396830112;  // C#8   4434.922 Hz
            7'd110: phase_inc = 32'd420426858;  // D8    4698.636 Hz
            7'd111: phase_inc = 32'd445426740;  // D#8   4978.032 Hz
            7'd112: phase_inc = 32'd471913192;  // E8    5274.041 Hz
            7'd113: phase_inc = 32'd499974611;  // F8    5587.652 Hz
            7'd114: phase_inc = 32'd529704648;  // F#8   5919.911 Hz
            7'd115: phase_inc = 32'd561202526;  // G8    6271.927 Hz
            7'd116: phase_inc = 32'd594573365;  // G#8   6644.875 Hz
            7'd117: phase_inc = 32'd629928537;  // A8    7040.000 Hz
            7'd118: phase_inc = 32'd667386037;  // A#8   7458.620 Hz
            7'd119: phase_inc = 32'd707070876;  // B8    7902.133 Hz

            7'd120: phase_inc = 32'd749115498;  // C9    8372.018 Hz
            7'd121: phase_inc = 32'd793660223;  // C#9   8869.844 Hz
            7'd122: phase_inc = 32'd840853716;  // D9    9397.273 Hz
            7'd123: phase_inc = 32'd890853480;  // D#9   9956.063 Hz
            7'd124: phase_inc = 32'd943826385;  // E9    10548.082 Hz
            7'd125: phase_inc = 32'd999949222;  // F9    11175.303 Hz
            7'd126: phase_inc = 32'd1059409297; // F#9   11839.822 Hz
            7'd127: phase_inc = 32'd1122405052; // G9    12543.854 Hz

            default: phase_inc = 32'd39370534;  // A4 default (440.000 Hz)

        endcase
    end

endmodule

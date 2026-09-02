`timescale 1ns / 1ps

//==========================================================================
// Top_Synth_SPI (V5)  - live 10-voice synth + independent FPGA-timed
//   mono sequencer with its own 2-voice bank, waveform, filter, and volume.
//==========================================================================

module Top_Synth_SPI(
    input  wire clk,
    input  wire midi_rx,
    input  wire spi_sclk, input wire spi_mosi, input wire spi_cs_n,
    output wire i2s_bclk, output wire i2s_lrclk, output wire i2s_sdin,
    output wire led0
);
    wire clk_audio, pll_locked;
    clk_wiz_0 audio_clock_generator(.clk_in1(clk),.reset(1'b0),.clk_out1(clk_audio),.locked(pll_locked));
    wire reset;
    Reset_sync reset_generator(.clk(clk_audio),.pll_locked(pll_locked),.reset(reset));

    // ---- SPI ----
    wire [7:0] wa; wire [15:0] wd; wire we;
    Spi_slave spi_receiver(.clk(clk_audio),.reset(reset),
        .spi_sclk(spi_sclk),.spi_mosi(spi_mosi),.spi_cs_n(spi_cs_n),
        .wr_addr(wa),.wr_data(wd),.wr_en(we));

    // ---- register file ----
    wire [15:0] attack_step,decay_step,sustain_level,release_step,pulse_width;
    wire [2:0]  detune_level;
    wire [15:0] filter_f,master_volume; wire [3:0] waveform_select;
    wire [9:0]  voice_enable_mask; wire master_mute,filter_bypass,osc_b_enable;
    wire [15:0] filter_q; wire [1:0] filter_type;
    wire seq_run; wire [3:0] seq_length; wire [15:0] seq_step_period,seq_gate_length;
    wire [127:0] seq_steps;
    wire [15:0] s_attack,s_decay,s_sustain,s_release,s_pulse_width;
    wire [2:0]  s_detune; wire [15:0] s_filter_f,s_volume; wire [3:0] s_waveform;
    wire s_mute,s_filter_bypass,s_osc_b; wire [15:0] s_filter_q; wire [1:0] s_filter_type;

    Param_regfile registers(.clk(clk_audio),.reset(reset),.wr_en(we),.wr_addr(wa),.wr_data(wd),
        .attack_step(attack_step),.decay_step(decay_step),.sustain_level(sustain_level),
        .release_step(release_step),.pulse_width(pulse_width),.detune_level(detune_level),
        .filter_f(filter_f),.master_volume(master_volume),.waveform_select(waveform_select),
        .voice_enable_mask(voice_enable_mask),.master_mute(master_mute),
        .filter_bypass(filter_bypass),.osc_b_enable(osc_b_enable),.filter_q(filter_q),
        .filter_type(filter_type),
        .seq_run(seq_run),.seq_length(seq_length),.seq_step_period(seq_step_period),
        .seq_gate_length(seq_gate_length),.seq_steps(seq_steps),
        .s_attack(s_attack),.s_decay(s_decay),.s_sustain(s_sustain),.s_release(s_release),
        .s_pulse_width(s_pulse_width),.s_detune(s_detune),.s_filter_f(s_filter_f),
        .s_volume(s_volume),.s_waveform(s_waveform),.s_mute(s_mute),
        .s_filter_bypass(s_filter_bypass),.s_osc_b(s_osc_b),.s_filter_q(s_filter_q),
        .s_filter_type(s_filter_type));

    // ---- MIDI notes (live, 10 voices) ----
    wire [7:0] mb; wire mv;
    Midi_rx #(.CLKS_PER_BIT(393)) midi_receiver(.clk(clk_audio),.reset(reset),.rx(midi_rx),
        .midi_byte(mb),.midi_valid(mv));
    wire [69:0] notes; wire [9:0] gates;
    Midi_note_poly10 note_logic(.clk(clk_audio),.reset(reset),.midi_byte(mb),
        .midi_byte_valid(mv),.notes(notes),.gates(gates));

    wire sample_tick;
    wire signed [15:0] vs [0:9];
    genvar i;
    generate for (i=0;i<10;i=i+1) begin: vg
        wire [6:0] note_i = notes[i*7 +: 7];
        wire [31:0] praw; reg [31:0] pr=0;
        Note_to_phase n2p(.midi_note(note_i),.phase_inc(praw));
        always @(posedge clk_audio) pr <= reset?0:praw;
        Voice_core v(.clk(clk_audio),.reset(reset),.sample_tick(sample_tick),
            .phase_inc(pr),.waveform(waveform_select),.pulse_width(pulse_width),
            .detune_level(detune_level),.osc_b_enable(osc_b_enable),.gate(gates[i]),
            .attack_step(attack_step),.decay_step(decay_step),.sustain_level(sustain_level),
            .release_step(release_step),.voice_sample(vs[i]));
    end endgenerate

    integer k; reg signed [20:0] mix_acc;
    always @(*) begin mix_acc=0;
        for (k=0;k<10;k=k+1) mix_acc = mix_acc + (voice_enable_mask[k] ? $signed(vs[k]) : 21'sd0);
    end
    wire signed [17:0] mix_full = mix_acc >>> 3;
    wire signed [15:0] main_mix =
        (mix_full>18'sd32767)?16'sd32767:(mix_full<-18'sd32768)?-16'sd32768:mix_full[15:0];

    // main filter + volume
    wire signed [15:0] main_filt;
    Svf_filter svf_main(.clk(clk_audio),.reset(reset),.sample_tick(sample_tick),
        .in_sample(main_mix),.f_coeff(filter_f),.q_coeff(filter_q),.ftype(filter_type),
        .out_sample(main_filt));
    wire signed [15:0] main_pf = filter_bypass ? main_mix : main_filt;
    wire signed [32:0] main_vm = $signed(main_pf)*$signed({1'b0,master_volume});
    wire signed [17:0] main_vf = main_vm >>> 15;
    wire signed [15:0] main_out_pre =
        (main_vf>18'sd32767)?16'sd32767:(main_vf<-18'sd32768)?-16'sd32768:main_vf[15:0];
    wire signed [15:0] main_out = master_mute ? 16'sd0 : main_out_pre;

    // ---- SEQUENCER: FPGA-timed, 2-voice bank ----
    wire [6:0] sna,snb; wire sga,sgb; wire [3:0] cur_step;
    Sequencer seq(.clk(clk_audio),.reset(reset),.run(seq_run),.length(seq_length),
        .step_period(seq_step_period),.gate_length(seq_gate_length),.steps(seq_steps),
        .note_a(sna),.gate_a(sga),.note_b(snb),.gate_b(sgb),.cur_step(cur_step));

    wire [31:0] spra,sprb; reg [31:0] spa=0,spb=0;
    Note_to_phase sn2a(.midi_note(sna),.phase_inc(spra));
    Note_to_phase sn2b(.midi_note(snb),.phase_inc(sprb));
    always @(posedge clk_audio) begin spa<=reset?0:spra; spb<=reset?0:sprb; end

    wire signed [15:0] sv0,sv1;
    Voice_core svoice0(.clk(clk_audio),.reset(reset),.sample_tick(sample_tick),
        .phase_inc(spa),.waveform(s_waveform),.pulse_width(s_pulse_width),
        .detune_level(s_detune),.osc_b_enable(s_osc_b),.gate(sga),
        .attack_step(s_attack),.decay_step(s_decay),.sustain_level(s_sustain),
        .release_step(s_release),.voice_sample(sv0));
    Voice_core svoice1(.clk(clk_audio),.reset(reset),.sample_tick(sample_tick),
        .phase_inc(spb),.waveform(s_waveform),.pulse_width(s_pulse_width),
        .detune_level(s_detune),.osc_b_enable(s_osc_b),.gate(sgb),
        .attack_step(s_attack),.decay_step(s_decay),.sustain_level(s_sustain),
        .release_step(s_release),.voice_sample(sv1));

    wire signed [16:0] seq_sum = $signed(sv0)+$signed(sv1);
    wire signed [15:0] seq_mix =
        (seq_sum>17'sd32767)?16'sd32767:(seq_sum<-17'sd32768)?-16'sd32768:seq_sum[15:0];
    wire signed [15:0] seq_filt;
    Svf_filter svf_seq(.clk(clk_audio),.reset(reset),.sample_tick(sample_tick),
        .in_sample(seq_mix),.f_coeff(s_filter_f),.q_coeff(s_filter_q),.ftype(s_filter_type),
        .out_sample(seq_filt));
    wire signed [15:0] seq_pf = s_filter_bypass ? seq_mix : seq_filt;
    wire signed [32:0] seq_vm = $signed(seq_pf)*$signed({1'b0,s_volume});
    wire signed [17:0] seq_vf = seq_vm >>> 15;
    wire signed [15:0] seq_out_pre =
        (seq_vf>18'sd32767)?16'sd32767:(seq_vf<-18'sd32768)?-16'sd32768:seq_vf[15:0];
    wire signed [15:0] seq_out = s_mute ? 16'sd0 : seq_out_pre;

    // ---- combine both banks ----
    wire signed [16:0] combined = $signed(main_out)+$signed(seq_out);
    wire signed [15:0] audio_sample =
        (combined>17'sd32767)?16'sd32767:(combined<-17'sd32768)?-16'sd32768:combined[15:0];

    I2S_Tx_32 i2s_output(.clk(clk_audio),.reset(reset),
        .left_sample(audio_sample),.right_sample(audio_sample),
        .bclk(i2s_bclk),.lrclk(i2s_lrclk),.sdin(i2s_sdin),.sample_tick(sample_tick));

    assign led0 = pll_locked ? ((|gates | sga | sgb) ? 1'b1 : ~master_mute) : 1'b0;
endmodule

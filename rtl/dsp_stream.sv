// dsp_stream: streaming fixed-point sample conditioner.
//
//   s_* -> input FIFO -> gain -> FIR -> decimator -> limiter -> output FIFO -> m_*
module dsp_stream (
  input  logic        clk,
  input  logic        rst_n,
  // Sample input
  input  logic        s_valid,
  output logic        s_ready,
  input  logic [15:0] s_data,
  input  logic        s_last,
  // Sample output
  output logic        m_valid,
  input  logic        m_ready,
  output logic [15:0] m_data,
  output logic        m_last,
  // Configuration port
  input  logic        cfg_we,
  input  logic [7:0]  cfg_addr,
  input  logic [31:0] cfg_wdata,
  output logic [31:0] cfg_rdata,
  output logic        cfg_err,
  // Interrupt
  output logic        irq
);

  logic        enable, fir_bypass, clear_on_last;
  logic [1:0]  round_mode, decim;
  logic signed [15:0] offset, gain, lim_hi, lim_lo;
  logic [3:0]  ntaps;
  logic [15:0] coef [dsp_pkg::MAX_TAPS];
  logic [15:0] stat_in, stat_out, stat_clip, peak_max, peak_min;
  logic        stat_clear;

  logic        inf_ready, inf_valid, inf_last;
  logic [15:0] inf_data;
  logic        gain_ready, gain_valid, gain_last, gain_clip;
  logic signed [15:0] gain_data;
  logic        fir_ready, fir_valid, fir_last, fir_clip, fir_active;
  logic signed [15:0] fir_data;
  logic        dec_ready, dec_valid, dec_last, dec_clip;
  logic signed [15:0] dec_data;
  logic signed [15:0] lim_data;
  logic        lim_clipped;
  logic        ouf_ready;
  logic [16:0] ouf_data;
  logic        push_fire, clip_event, frame_event;
  logic        busy, fifo_empty;

  assign s_ready = enable && inf_ready;

  dsp_fifo #(.WIDTH(17), .DEPTH(2)) u_in_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .push_valid (s_valid && enable),
    .push_ready (inf_ready),
    .push_data  ({s_last, s_data}),
    .pop_valid  (inf_valid),
    .pop_ready  (gain_ready),
    .pop_data   ({inf_last, inf_data})
  );

  dsp_gain u_gain (
    .clk        (clk),
    .rst_n      (rst_n),
    .offset     (offset),
    .gain       (gain),
    .round_mode (round_mode),
    .in_valid   (inf_valid),
    .in_ready   (gain_ready),
    .in_data    ($signed(inf_data)),
    .in_last    (inf_last),
    .out_valid  (gain_valid),
    .out_ready  (fir_ready),
    .out_data   (gain_data),
    .out_last   (gain_last),
    .out_clip   (gain_clip)
  );

  dsp_fir u_fir (
    .clk           (clk),
    .rst_n         (rst_n),
    .bypass        (fir_bypass),
    .clear_on_last (clear_on_last),
    .ntaps         (ntaps),
    .coef          (coef),
    .round_mode    (round_mode),
    .in_valid      (gain_valid),
    .in_ready      (fir_ready),
    .in_data       (gain_data),
    .in_last       (gain_last),
    .in_clip       (gain_clip),
    .out_valid     (fir_valid),
    .out_ready     (dec_ready),
    .out_data      (fir_data),
    .out_last      (fir_last),
    .out_clip      (fir_clip),
    .active        (fir_active)
  );

  dsp_decim u_decim (
    .clk        (clk),
    .rst_n      (rst_n),
    .decim      (decim),
    .round_mode (round_mode),
    .in_valid   (fir_valid),
    .in_ready   (dec_ready),
    .in_data    (fir_data),
    .in_last    (fir_last),
    .in_clip    (fir_clip),
    .out_valid  (dec_valid),
    .out_ready  (ouf_ready),
    .out_data   (dec_data),
    .out_last   (dec_last),
    .out_clip   (dec_clip)
  );

  dsp_limit u_limit (
    .lim_hi   (lim_hi),
    .lim_lo   (lim_lo),
    .in_data  (dec_data),
    .out_data (lim_data),
    .clipped  (lim_clipped)
  );

  dsp_fifo #(.WIDTH(17), .DEPTH(8)) u_out_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .push_valid (dec_valid),
    .push_ready (ouf_ready),
    .push_data  ({dec_last, $unsigned(lim_data)}),
    .pop_valid  (m_valid),
    .pop_ready  (m_ready),
    .pop_data   (ouf_data)
  );

  assign m_data = ouf_data[15:0];
  assign m_last = ouf_data[16];

  assign push_fire   = dec_valid && ouf_ready;
  assign clip_event  = push_fire && (dec_clip || lim_clipped);
  assign frame_event = m_valid && m_ready && m_last;
  assign fifo_empty  = !m_valid;
  assign busy        = inf_valid || gain_valid || fir_active || dec_valid || m_valid;

  dsp_stats u_stats (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear      (stat_clear),
    .in_fire    (s_valid && s_ready),
    .out_fire   (m_valid && m_ready),
    .out_data   ($signed(m_data)),
    .clip_event (clip_event),
    .stat_in    (stat_in),
    .stat_out   (stat_out),
    .stat_clip  (stat_clip),
    .peak_max   (peak_max),
    .peak_min   (peak_min)
  );

  dsp_regs u_regs (
    .clk           (clk),
    .rst_n         (rst_n),
    .cfg_we        (cfg_we),
    .cfg_addr      (cfg_addr),
    .cfg_wdata     (cfg_wdata),
    .cfg_rdata     (cfg_rdata),
    .cfg_err       (cfg_err),
    .enable        (enable),
    .fir_bypass    (fir_bypass),
    .round_mode    (round_mode),
    .decim         (decim),
    .clear_on_last (clear_on_last),
    .offset        (offset),
    .gain          (gain),
    .lim_hi        (lim_hi),
    .lim_lo        (lim_lo),
    .ntaps         (ntaps),
    .coef_flat     (coef),
    .busy          (busy),
    .fifo_empty    (fifo_empty),
    .stat_in       (stat_in),
    .stat_out      (stat_out),
    .stat_clip     (stat_clip),
    .peak_max      (peak_max),
    .peak_min      (peak_min),
    .stat_clear    (stat_clear),
    .ev_clip       (clip_event),
    .ev_frame      (frame_event),
    .irq           (irq)
  );

endmodule

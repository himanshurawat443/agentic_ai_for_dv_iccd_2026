// dsp_regs: configuration register block.
module dsp_regs (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        cfg_we,
  input  logic [7:0]  cfg_addr,
  input  logic [31:0] cfg_wdata,
  output logic [31:0] cfg_rdata,
  output logic        cfg_err,
  // Configuration outputs
  output logic        enable,
  output logic        fir_bypass,
  output logic [1:0]  round_mode,
  output logic [1:0]  decim,
  output logic        clear_on_last,
  output logic signed [15:0] offset,
  output logic signed [15:0] gain,
  output logic signed [15:0] lim_hi,
  output logic signed [15:0] lim_lo,
  output logic [3:0]  ntaps,
  output logic [15:0] coef_flat [dsp_pkg::MAX_TAPS],
  // Status inputs
  input  logic        busy,
  input  logic        fifo_empty,
  input  logic [15:0] stat_in,
  input  logic [15:0] stat_out,
  input  logic [15:0] stat_clip,
  input  logic [15:0] peak_max,
  input  logic [15:0] peak_min,
  output logic        stat_clear,
  // Interrupt events
  input  logic        ev_clip,
  input  logic        ev_frame,
  output logic        irq
);

  logic [5:0]  word;
  logic [6:0]  ctrl_q;
  logic [15:0] offset_q, gain_q, hi_q, lo_q;
  logic [3:0]  ntaps_q;
  logic [15:0] coef_q [dsp_pkg::MAX_TAPS];
  logic [1:0]  irq_stat_q, irq_en_q;
  logic        is_coef;
  logic [2:0]  coef_idx;
  logic        mapped;
  logic        unused_bits;

  assign unused_bits = &{1'b0, cfg_addr[1:0], cfg_wdata[31:16]};

  assign word     = cfg_addr[7:2];
  assign is_coef  = (word >= dsp_pkg::A_COEF0) && (word <= dsp_pkg::A_COEF7);
  assign coef_idx = word[2:0];
  assign mapped   = (word <= dsp_pkg::A_IRQ_EN);
  assign cfg_err  = !mapped;

  assign enable        = ctrl_q[0];
  assign fir_bypass    = ctrl_q[1];
  assign round_mode    = ctrl_q[3:2];
  assign decim         = ctrl_q[5:4];
  assign clear_on_last = ctrl_q[6];
  assign offset        = $signed(offset_q);
  assign gain          = $signed(gain_q);
  assign lim_hi        = $signed(hi_q);
  assign lim_lo        = $signed(lo_q);
  assign ntaps         = ntaps_q;
  assign stat_clear    = cfg_we && (word == dsp_pkg::A_STAT_CLR) && cfg_wdata[0];
  assign irq           = |(irq_stat_q & irq_en_q);

  always_comb begin
    for (int i = 0; i < dsp_pkg::MAX_TAPS; i++) begin
      coef_flat[i] = coef_q[i];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_q   <= 7'b000_0010;
      offset_q <= 16'h0000;
      gain_q   <= dsp_pkg::GAIN_UNITY;
      hi_q     <= dsp_pkg::SAMPLE_MAX;
      lo_q     <= dsp_pkg::SAMPLE_MIN;
      ntaps_q  <= 4'd1;
      irq_en_q <= 2'b00;
    end else if (cfg_we) begin
      unique case (word)
        dsp_pkg::A_CTRL:   ctrl_q   <= cfg_wdata[6:0];
        dsp_pkg::A_OFFSET: offset_q <= cfg_wdata[15:0];
        dsp_pkg::A_GAIN:   gain_q   <= cfg_wdata[15:0];
        dsp_pkg::A_LIM_HI: hi_q     <= cfg_wdata[15:0];
        dsp_pkg::A_LIM_LO: lo_q     <= cfg_wdata[15:0];
        dsp_pkg::A_NTAPS: begin
          if ((cfg_wdata[3:0] >= 4'd1) && (cfg_wdata[3:0] <= 4'd8)) begin
            ntaps_q <= cfg_wdata[3:0];
          end
        end
        dsp_pkg::A_IRQ_EN: irq_en_q <= cfg_wdata[1:0];
        default: ;
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < dsp_pkg::MAX_TAPS; i++) begin
        coef_q[i] <= 16'h0000;
      end
    end else if (cfg_we && is_coef) begin
      coef_q[coef_idx] <= cfg_wdata[15:0];
    end
  end

  // IRQ status: write 1 to clear, a simultaneous event wins.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      irq_stat_q <= 2'b00;
    end else begin
      if (cfg_we && (word == dsp_pkg::A_IRQ_STAT)) begin
        irq_stat_q <= (irq_stat_q & ~cfg_wdata[1:0]) | {ev_frame, ev_clip};
      end else begin
        irq_stat_q <= irq_stat_q | {ev_frame, ev_clip};
      end
    end
  end

  always_comb begin
    cfg_rdata = 32'h0;
    if (is_coef) begin
      cfg_rdata = {16'h0, coef_q[coef_idx]};
    end else begin
      unique case (word)
        dsp_pkg::A_ID:        cfg_rdata = dsp_pkg::UNIT_ID;
        dsp_pkg::A_CTRL:      cfg_rdata = {25'h0, ctrl_q};
        dsp_pkg::A_OFFSET:    cfg_rdata = {16'h0, offset_q};
        dsp_pkg::A_GAIN:      cfg_rdata = {16'h0, gain_q};
        dsp_pkg::A_LIM_HI:    cfg_rdata = {16'h0, hi_q};
        dsp_pkg::A_LIM_LO:    cfg_rdata = {16'h0, lo_q};
        dsp_pkg::A_NTAPS:     cfg_rdata = {28'h0, ntaps_q};
        dsp_pkg::A_STATUS:    cfg_rdata = {30'h0, fifo_empty, busy};
        dsp_pkg::A_STAT_IN:   cfg_rdata = {16'h0, stat_in};
        dsp_pkg::A_STAT_OUT:  cfg_rdata = {16'h0, stat_out};
        dsp_pkg::A_STAT_CLIP: cfg_rdata = {16'h0, stat_clip};
        dsp_pkg::A_PEAK_MAX:  cfg_rdata = {16'h0, peak_max};
        dsp_pkg::A_PEAK_MIN:  cfg_rdata = {16'h0, peak_min};
        dsp_pkg::A_IRQ_STAT:  cfg_rdata = {30'h0, irq_stat_q};
        dsp_pkg::A_IRQ_EN:    cfg_rdata = {30'h0, irq_en_q};
        default:              cfg_rdata = 32'h0;
      endcase
    end
  end

endmodule

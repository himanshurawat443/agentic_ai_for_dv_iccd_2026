// dsp_stats: sample counters, clip counter and peak hold.
module dsp_stats (
  input  logic               clk,
  input  logic               rst_n,
  input  logic               clear,
  input  logic               in_fire,
  input  logic               out_fire,
  input  logic signed [15:0] out_data,
  input  logic               clip_event,
  output logic [15:0]        stat_in,
  output logic [15:0]        stat_out,
  output logic [15:0]        stat_clip,
  output logic [15:0]        peak_max,
  output logic [15:0]        peak_min
);

  logic [15:0] in_q, out_q, clip_q;
  logic signed [15:0] max_q, min_q;

  assign stat_in   = in_q;
  assign stat_out  = out_q;
  assign stat_clip = clip_q;
  assign peak_max  = max_q;
  assign peak_min  = min_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_q   <= 16'd0;
      out_q  <= 16'd0;
      clip_q <= 16'd0;
    end else if (clear) begin
      in_q   <= 16'd0;
      out_q  <= 16'd0;
      clip_q <= 16'd0;
    end else begin
      if (in_fire && (in_q != 16'hFFFF)) begin
        in_q <= in_q + 16'd1;
      end
      if (out_fire && (out_q != 16'hFFFF)) begin
        out_q <= out_q + 16'd1;
      end
      if (clip_event && (clip_q != 16'hFFFF)) begin
        clip_q <= clip_q + 16'd1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_q <= $signed(dsp_pkg::SAMPLE_MIN);
      min_q <= $signed(dsp_pkg::SAMPLE_MAX);
    end else if (clear) begin
      max_q <= 16'sd0;
      min_q <= 16'sd0;
    end else if (out_fire) begin
      if (out_data > max_q) begin
        max_q <= out_data;
      end
      if (out_data < min_q) begin
        min_q <= out_data;
      end
    end
  end

endmodule

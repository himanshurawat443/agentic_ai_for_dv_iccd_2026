// dsp_decim: boxcar decimator. Sums groups of 2^decim samples and emits the sum
// shifted right by decim. The last sample of a frame closes the open group.
module dsp_decim (
  input  logic               clk,
  input  logic               rst_n,
  input  logic [1:0]         decim,
  input  logic [1:0]         round_mode,
  input  logic               in_valid,
  output logic               in_ready,
  input  logic signed [15:0] in_data,
  input  logic               in_last,
  input  logic               in_clip,
  output logic               out_valid,
  input  logic               out_ready,
  output logic signed [15:0] out_data,
  output logic               out_last,
  output logic               out_clip
);

  logic [2:0]         phase_q;
  logic signed [18:0] sum_q;
  logic               clip_q;
  logic               valid_q;
  logic signed [15:0] data_q;
  logic               last_q;
  logic               oclip_q;

  logic [2:0]         group_max;
  logic               group_full;
  logic               close_group;
  logic               accept;
  logic signed [18:0] sum_next;
  logic signed [15:0] avg;
  logic               sat;

  assign group_max   = (3'b001 << decim) - 3'b001;
  assign group_full  = (phase_q == group_max);
  assign close_group = group_full || in_last;
  assign sum_next    = sum_q + 19'(in_data);

  dsp_rndsat #(.IN_W(19)) u_round (
    .value     (sum_next),
    .shift     ({2'b00, decim}),
    .mode      (round_mode),
    .result    (avg),
    .saturated (sat)
  );

  assign in_ready  = !valid_q || out_ready;
  assign accept    = in_valid && in_ready;
  assign out_valid = valid_q;
  assign out_data  = data_q;
  assign out_last  = last_q;
  assign out_clip  = oclip_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      phase_q <= 3'd0;
      sum_q   <= 19'sd0;
      clip_q  <= 1'b0;
    end else if (accept) begin
      if (group_full) begin
        phase_q <= 3'd0;
        sum_q   <= 19'sd0;
        clip_q  <= 1'b0;
      end else begin
        phase_q <= phase_q + 3'd1;
        sum_q   <= sum_next;
        clip_q  <= clip_q || in_clip;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_q <= 1'b0;
      data_q  <= 16'sd0;
      last_q  <= 1'b0;
      oclip_q <= 1'b0;
    end else if (in_ready) begin
      valid_q <= in_valid && close_group;
      if (in_valid && close_group) begin
        data_q  <= avg;
        last_q  <= in_last;
        oclip_q <= clip_q || in_clip || sat;
      end
    end
  end

endmodule

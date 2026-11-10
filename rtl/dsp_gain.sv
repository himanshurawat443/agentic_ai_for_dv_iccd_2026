// dsp_gain: subtracts the programmable offset and applies a Q8.8 gain.
module dsp_gain (
  input  logic               clk,
  input  logic               rst_n,
  input  logic signed [15:0] offset,
  input  logic signed [15:0] gain,
  input  logic [1:0]         round_mode,
  input  logic               in_valid,
  output logic               in_ready,
  input  logic signed [15:0] in_data,
  input  logic               in_last,
  output logic               out_valid,
  input  logic               out_ready,
  output logic signed [15:0] out_data,
  output logic               out_last,
  output logic               out_clip
);

  logic signed [16:0] centered;
  logic signed [32:0] product;
  logic signed [15:0] scaled;
  logic               sat;

  logic               valid_q;
  logic signed [15:0] data_q;
  logic               last_q;
  logic               clip_q;

  assign centered = 17'(in_data) - 17'(offset);
  assign product  = centered * 33'(gain);

  dsp_rndsat #(.IN_W(33)) u_round (
    .value     (product),
    .shift     (4'd8),
    .mode      (round_mode),
    .result    (scaled),
    .saturated (sat)
  );

  assign in_ready  = !valid_q || out_ready;
  assign out_valid = valid_q;
  assign out_data  = data_q;
  assign out_last  = last_q;
  assign out_clip  = clip_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_q <= 1'b0;
      data_q  <= 16'sd0;
      last_q  <= 1'b0;
      clip_q  <= 1'b0;
    end else if (in_ready) begin
      valid_q <= in_valid;
      if (in_valid) begin
        data_q <= scaled;
        last_q <= in_last;
        clip_q <= sat;
      end
    end
  end

endmodule

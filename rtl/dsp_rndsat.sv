// dsp_rndsat: arithmetic right shift with selectable rounding, then saturation
// to a signed 16-bit sample.
module dsp_rndsat #(
  parameter int IN_W = 40
) (
  input  logic signed [IN_W-1:0] value,
  input  logic [3:0]             shift,
  input  logic [1:0]             mode,
  output logic signed [15:0]     result,
  output logic                   saturated
);

  logic signed [IN_W-1:0] kept;
  logic [IN_W-1:0]        mask;
  logic [IN_W-1:0]        dropped;
  logic [IN_W-1:0]        half;
  logic                   has_frac;
  logic                   frac_ge_half;
  logic                   frac_gt_half;
  logic                   inc;
  logic signed [IN_W:0]   rounded;
  logic                   over_hi;
  logic                   over_lo;

  assign kept     = value >>> shift;
  assign mask     = ~({IN_W{1'b1}} << shift);
  assign dropped  = $unsigned(value) & mask;
  assign has_frac = (shift != 4'd0);
  assign half     = {{(IN_W-1){1'b0}}, has_frac} << (shift - 4'd1);

  assign frac_ge_half = has_frac && (dropped >= half);
  assign frac_gt_half = has_frac && (dropped > half);

  always_comb begin
    unique case (mode)
      dsp_pkg::RND_FLOOR:     inc = 1'b0;
      dsp_pkg::RND_HALF_UP:   inc = frac_ge_half;
      dsp_pkg::RND_HALF_EVEN: inc = frac_ge_half && kept[0];
      dsp_pkg::RND_RESERVED:  inc = 1'b0;
    endcase
  end

  assign rounded = $signed({kept[IN_W-1], kept}) + $signed({{IN_W{1'b0}}, inc});

  assign over_hi = (rounded > $signed((IN_W+1)'(32767)));
  assign over_lo = (rounded < -$signed((IN_W+1)'(32768)));

  assign saturated = over_hi || over_lo;

  always_comb begin
    if (over_hi) begin
      result = 16'sh7FFF;
    end else if (over_lo) begin
      result = 16'sh8001;
    end else begin
      result = rounded[15:0];
    end
  end

endmodule

// dsp_limit: clamps a sample to the programmed window. LIM_HI wins if the
// window is empty.
module dsp_limit (
  input  logic signed [15:0] lim_hi,
  input  logic signed [15:0] lim_lo,
  input  logic signed [15:0] in_data,
  output logic signed [15:0] out_data,
  output logic               clipped
);

  logic over, under;

  assign over    = (in_data > lim_hi);
  assign under   = (in_data < lim_lo);
  assign clipped = over || under;

  always_comb begin
    if (over) begin
      out_data = lim_hi;
    end else if (under) begin
      out_data = lim_lo;
    end else begin
      out_data = in_data;
    end
  end

endmodule

// dsp_fir: programmable FIR filter with one shared multiplier.
// One sample takes NTAPS + 3 cycles; with bypass set the stage is a wire.
module dsp_fir (
  input  logic               clk,
  input  logic               rst_n,
  input  logic               bypass,
  input  logic               clear_on_last,
  input  logic [3:0]         ntaps,
  input  logic [15:0]        coef [dsp_pkg::MAX_TAPS],
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
  output logic               out_clip,
  output logic               active
);

  typedef enum logic [1:0] {S_IDLE, S_MAC, S_ACC, S_DONE} state_t;

  state_t             state_q;
  logic [15:0]        delay_q [dsp_pkg::MAX_TAPS];
  logic [3:0]         idx_q;
  logic signed [31:0] prod_q;
  logic signed [39:0] acc_q;
  logic               last_q;
  logic               clip_q;
  logic               take;

  logic signed [15:0] filtered;
  logic               sat;

  dsp_rndsat #(.IN_W(40)) u_round (
    .value     (acc_q),
    .shift     (4'd15),
    .mode      (round_mode),
    .result    (filtered),
    .saturated (sat)
  );

  assign active = (state_q != S_IDLE);
  assign take   = !bypass && in_valid && (state_q == S_IDLE);

  always_comb begin
    if (bypass && (state_q == S_IDLE)) begin
      in_ready  = out_ready;
      out_valid = in_valid;
      out_data  = in_data;
      out_last  = in_last;
      out_clip  = in_clip;
    end else begin
      in_ready  = (state_q == S_IDLE);
      out_valid = (state_q == S_DONE);
      out_data  = filtered;
      out_last  = last_q;
      out_clip  = clip_q || sat;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= S_IDLE;
      idx_q   <= 4'd0;
      prod_q  <= 32'sd0;
      acc_q   <= 40'sd0;
      last_q  <= 1'b0;
      clip_q  <= 1'b0;
    end else begin
      unique case (state_q)
        S_IDLE: begin
          if (take) begin
            state_q <= S_MAC;
            idx_q   <= 4'd0;
            acc_q   <= 40'sd0;
            last_q  <= in_last;
            clip_q  <= in_clip;
          end
        end
        S_MAC: begin
          prod_q  <= $signed(coef[idx_q[2:0]]) * $signed(delay_q[idx_q[2:0]]);
          state_q <= S_ACC;
        end
        S_ACC: begin
          acc_q <= acc_q + 40'(prod_q);
          idx_q <= idx_q + 4'd1;
          if (idx_q + 4'd1 == ntaps) begin
            state_q <= S_DONE;
          end else begin
            state_q <= S_MAC;
          end
        end
        S_DONE: begin
          if (out_ready) begin
            state_q <= S_IDLE;
          end
        end
      endcase
    end
  end

  // Delay line: newest sample at index 0.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < dsp_pkg::MAX_TAPS; i++) begin
        delay_q[i] <= 16'h0000;
      end
    end else if (take) begin
      delay_q[0] <= in_data;
      for (int i = 1; i < dsp_pkg::MAX_TAPS; i++) begin
        delay_q[i] <= delay_q[i-1];
      end
    end else if ((state_q == S_DONE) && out_ready && last_q && clear_on_last) begin
      for (int i = 0; i < dsp_pkg::MAX_TAPS; i++) begin
        delay_q[i] <= 16'h0000;
      end
    end
  end

endmodule

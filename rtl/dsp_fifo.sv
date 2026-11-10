// dsp_fifo: synchronous FIFO with first-word fall-through.
module dsp_fifo #(
  parameter int WIDTH = 18,
  parameter int DEPTH = 8
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic             push_valid,
  output logic             push_ready,
  input  logic [WIDTH-1:0] push_data,
  output logic             pop_valid,
  input  logic             pop_ready,
  output logic [WIDTH-1:0] pop_data
);

  localparam int AW = $clog2(DEPTH);

  logic [WIDTH-1:0] mem_q [DEPTH];
  logic [AW-1:0]    wptr_q, rptr_q;
  logic [AW:0]      count_q;
  logic             do_push, do_pop;

  assign push_ready = (count_q != (AW+1)'(DEPTH));
  assign pop_valid  = (count_q != '0);
  assign pop_data   = mem_q[rptr_q];
  assign do_push    = push_valid && push_ready;
  assign do_pop     = pop_valid && pop_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wptr_q  <= '0;
      rptr_q  <= '0;
      count_q <= '0;
    end else begin
      if (do_push) begin
        wptr_q <= (wptr_q == AW'(DEPTH - 1)) ? '0 : wptr_q + 1'b1;
      end
      if (do_pop) begin
        rptr_q <= (rptr_q == AW'(DEPTH - 1)) ? '0 : rptr_q + 1'b1;
      end
      if (do_push && !do_pop) begin
        count_q <= count_q + 1'b1;
      end else if (do_pop && !do_push) begin
        count_q <= count_q - 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < DEPTH; i++) begin
        mem_q[i] <= '0;
      end
    end else if (do_push) begin
      mem_q[wptr_q] <= push_data;
    end
  end

endmodule

// dsp_pkg: shared constants for the dsp_stream sample conditioner.
package dsp_pkg;

  parameter logic [31:0] UNIT_ID = 32'h4453_0100;

  parameter int MAX_TAPS = 8;

  // Rounding modes (CTRL.ROUND).
  parameter logic [1:0] RND_FLOOR    = 2'd0;
  parameter logic [1:0] RND_HALF_UP  = 2'd1;
  parameter logic [1:0] RND_HALF_EVEN = 2'd2;
  parameter logic [1:0] RND_RESERVED = 2'd3;

  // Register word offsets (cfg_addr[7:2]).
  parameter logic [5:0] A_ID        = 6'h00;
  parameter logic [5:0] A_CTRL      = 6'h01;
  parameter logic [5:0] A_OFFSET    = 6'h02;
  parameter logic [5:0] A_GAIN      = 6'h03;
  parameter logic [5:0] A_LIM_HI    = 6'h04;
  parameter logic [5:0] A_LIM_LO    = 6'h05;
  parameter logic [5:0] A_NTAPS     = 6'h06;
  parameter logic [5:0] A_STATUS    = 6'h07;
  parameter logic [5:0] A_COEF0     = 6'h08;
  parameter logic [5:0] A_COEF7     = 6'h0F;
  parameter logic [5:0] A_STAT_IN   = 6'h10;
  parameter logic [5:0] A_STAT_OUT  = 6'h11;
  parameter logic [5:0] A_STAT_CLIP = 6'h12;
  parameter logic [5:0] A_PEAK_MAX  = 6'h13;
  parameter logic [5:0] A_PEAK_MIN  = 6'h14;
  parameter logic [5:0] A_STAT_CLR  = 6'h15;
  parameter logic [5:0] A_IRQ_STAT  = 6'h16;
  parameter logic [5:0] A_IRQ_EN    = 6'h17;

  // Reset values.
  parameter logic [15:0] GAIN_UNITY = 16'h0100;
  parameter logic [15:0] SAMPLE_MAX = 16'h7FFF;
  parameter logic [15:0] SAMPLE_MIN = 16'h8000;

endpackage

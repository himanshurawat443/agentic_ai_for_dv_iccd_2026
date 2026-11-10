# Change Request CR-D1: Round toward zero and output frame length

Applies to: `dsp_stream` specification revision 1.0. Design 1.

## Motivation

Downstream filters need a rounding mode with no bias on either sign, and software needs to see how long the last output frame was without counting samples itself.

## Change

1. Section 5, CTRL.ROUND: value 3, reserved in revision 1.0, now selects round toward zero.
2. New requirement in section 6:
   - **REQ-18** With ROUND = 3, a value with a nonzero discarded fraction is rounded toward zero: a positive value is truncated, and a negative value is incremented after the floor shift. A value with no discarded fraction is unchanged. ROUND applies to every stage that rounds (REQ-14).
3. Section 5, add register LAST_LEN at offset 0x060, RO, field [15:0], reset value 0. The offset is now mapped. REQ-05 applies to the new offset set: offsets above 0x060 are unmapped.
4. New requirement in section 11:
   - **REQ-38** LAST_LEN holds the number of samples in the most recently completed output frame, counted at the `m_*` handshake, including the sample with `m_last` = 1. It updates in the cycle after that handshake, and holds its value between frames. A write to STAT_CLEAR with bit 0 = 1 sets LAST_LEN to 0 and restarts the count of the frame in progress. LAST_LEN is not specified for an output frame of more than 65535 samples.
5. No port changes. The identifier remains `0x44530100`.

## Acceptance

- With GAIN = 0x0040 (0.25) and ROUND = 3, inputs 9, 11, 15, -9, -11 and -15 give 2, 2, 3, -2, -2 and -3.
- After a frame of 7 samples is delivered, LAST_LEN reads 7. While the next frame is partly delivered it still reads 7.
- A read of offset 0x060 completes with `cfg_err` = 0.

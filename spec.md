# dsp_stream: Streaming Fixed-Point Sample Conditioner

Specification, revision 1.0. Design 1.

## 1. Overview

`dsp_stream` conditions a stream of signed 16-bit samples. Each sample passes through an offset and gain stage, an optional FIR filter, a boxcar decimator and a limiter, and leaves through an output FIFO. Software configures the unit through a simple register port. Samples are grouped into frames with a last flag.

Requirements are numbered `REQ-xx`. Every requirement is testable at the ports of `dsp_stream`. Text marked "Note" is informative.

Conventions. "Cycle" means one period of `clk`. A handshake occurs on a rising edge at which valid and ready are both 1. A register write takes effect on the rising edge at which `cfg_we` is 1. All samples and signed fields are two's complement.

## 2. Ports

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock. |
| `rst_n` | in | 1 | Asynchronous reset, active low. |
| `s_valid` | in | 1 | Input sample valid. |
| `s_ready` | out | 1 | Input sample ready. |
| `s_data` | in | 16 | Input sample, signed. |
| `s_last` | in | 1 | Marks the last sample of an input frame. |
| `m_valid` | out | 1 | Output sample valid. |
| `m_ready` | in | 1 | Output sample ready. |
| `m_data` | out | 16 | Output sample, signed. |
| `m_last` | out | 1 | Marks the last sample of an output frame. |
| `cfg_we` | in | 1 | Register write enable. |
| `cfg_addr` | in | 8 | Register byte address. |
| `cfg_wdata` | in | 32 | Register write data. |
| `cfg_rdata` | out | 32 | Register read data. |
| `cfg_err` | out | 1 | Address is unmapped. |
| `irq` | out | 1 | Interrupt request, active high. |

## 3. Reset

- **REQ-01** Every register field has the reset value given in section 5. All pipeline stages, the FIR delay line, the decimator and both FIFOs are empty or zero after reset.
- **REQ-02** Reset may be asserted at any time. After reset, `m_valid` = 0, `irq` = 0, and every register reads its reset value regardless of earlier writes or traffic.

## 4. Register port

- **REQ-03** `cfg_rdata` and `cfg_err` are combinational functions of `cfg_addr` and the register state. There is no read strobe, and a read has no side effect.
- **REQ-04** Address decode uses `cfg_addr[7:2]`; `cfg_addr[1:0]` are ignored.
- **REQ-05** `cfg_err` = 1 for every unmapped offset and 0 for every mapped offset. A read of an unmapped offset returns 0, and a write to it has no effect. Offsets above 0x05C are unmapped.
- **REQ-06** A write to a read-only register has no effect. Bits not defined for a register read as 0 and ignore writes.

## 5. Register map

| Offset | Name | Access | Fields |
|---|---|---|---|
| 0x000 | ID | RO | Reads `0x44530100`. |
| 0x004 | CTRL | RW | [0] ENABLE, reset 0. [1] FIR_BYPASS, reset 1. [3:2] ROUND, reset 0. [5:4] DECIM, reset 0. [6] CLEAR_ON_LAST, reset 0. |
| 0x008 | OFFSET | RW | [15:0] signed, reset 0. |
| 0x00C | GAIN | RW | [15:0] signed Q8.8, reset `0x0100` (1.0). |
| 0x010 | LIM_HI | RW | [15:0] signed, reset `0x7FFF`. |
| 0x014 | LIM_LO | RW | [15:0] signed, reset `0x8000`. |
| 0x018 | NTAPS | RW | [3:0] number of FIR taps, reset 1. Writes outside 1 to 8 are ignored. |
| 0x01C | STATUS | RO | [0] BUSY: a sample is in the pipeline or a FIFO. A sample held only in an open decimator group does not count. [1] EMPTY: `m_valid` = 0. |
| 0x020 + 4k | COEF(k) | RW | [15:0] signed Q1.15 coefficient, k = 0 to 7, reset 0. |
| 0x040 | STAT_IN | RO | [15:0] input samples accepted. |
| 0x044 | STAT_OUT | RO | [15:0] output samples delivered. |
| 0x048 | STAT_CLIP | RO | [15:0] clipped output samples (REQ-32). |
| 0x04C | PEAK_MAX | RO | [15:0] signed, reset `0x8000`. |
| 0x050 | PEAK_MIN | RO | [15:0] signed, reset `0x7FFF`. |
| 0x054 | STAT_CLEAR | WO | [0] write 1 to clear the statistics (REQ-37). Reads as 0. |
| 0x058 | IRQ_STATUS | W1C | [0] CLIP. [1] FRAME. Reset 0. |
| 0x05C | IRQ_ENABLE | RW | [1:0], reset 0. |

Note: software changes OFFSET, GAIN, LIM_HI, LIM_LO, NTAPS, COEF and the CTRL fields other than ENABLE only while STATUS.BUSY = 0. The result of a change while BUSY = 1 is not specified.

## 6. Data flow and rounding

- **REQ-07** Input and output use a valid and ready handshake. While `m_valid` = 1 and `m_ready` = 0, `m_valid`, `m_data` and `m_last` hold their values.
- **REQ-08** While ENABLE = 0, `s_ready` = 0. Samples already inside the unit still reach the output.
- **REQ-09** Output samples appear in input order. Latency is not specified, but with FIR_BYPASS = 1, DECIM = 0, `m_ready` held at 1 and a continuous input, the unit accepts and delivers one sample per cycle after its initial latency, and that latency is at most 16 cycles.
- **REQ-10** With FIR_BYPASS = 0, the unit accepts at least one sample every NTAPS * 2 + 8 cycles when the output is not stalled.
- **REQ-11** Output FIFO depth is at least 8 samples. Stalling `m_ready` eventually stalls `s_ready` and never loses a sample.
- **REQ-12** Each stage in sections 7 to 9 uses the same rounding and saturation operation, written RS(v, n) below: v is shifted right arithmetically by n bits, rounded according to CTRL.ROUND, and saturated to a signed 16-bit value.
- **REQ-13** A sample is marked clipped if RS saturates at any stage, or if the limiter changes its value (REQ-30). Marks combine across a decimation group.
- **REQ-14** CTRL.ROUND selects the rounding of RS. With the discarded fraction f in [0, 1): value 0 is floor, which discards f. Value 1 is round half up, which adds 1 to the floor result when f >= 1/2. Value 2 is round half to even, covered by REQ-16. Value 3 is reserved and behaves as value 0.
- **REQ-15** RS with n = 0 returns v unchanged except for saturation, for every ROUND value.
- **REQ-16** With ROUND = 2, the floor result gains 1 when f > 1/2, and when f = 1/2 and the floor result is odd. Otherwise it is unchanged.
- **REQ-17** RS saturates a result above 32767 to 32767, and a result below -32768 to -32768.

## 7. Offset and gain

- **REQ-19** The stage computes RS((x - OFFSET) * GAIN, 8), where the subtraction and product are computed without overflow.

## 8. FIR filter

- **REQ-20** With FIR_BYPASS = 1, the filter passes samples unchanged and its delay line holds its value.
- **REQ-21** With FIR_BYPASS = 0, each sample y from section 7 enters a delay line d, with d[0] the newest, and the stage outputs RS(sum of COEF(k) * d[k] for k = 0 to NTAPS - 1, 15).
- **REQ-22** The accumulator does not overflow for any legal coefficients and samples.
- **REQ-23** With CLEAR_ON_LAST = 1, the delay line is zero after the sample with the last flag leaves the filter. With CLEAR_ON_LAST = 0, the delay line carries over between frames.

## 9. Decimator

- **REQ-24** With DECIM = D, samples are grouped into up to G = 2^D samples. A group closes on its G-th sample or on a sample with the last flag, whichever comes first.
- **REQ-25** A closed group emits one sample, RS(sum of the group, D). The shift is D even when the group has fewer than G samples.
- **REQ-26** The emitted sample has the last flag if the closing sample has it.
- **REQ-27** After a group closes, for either reason, the next sample starts a new group with an empty sum and no clipped mark.

## 10. Limiter

- **REQ-28** A sample greater than LIM_HI becomes LIM_HI.
- **REQ-29** Otherwise, a sample less than LIM_LO becomes LIM_LO. LIM_HI therefore wins when LIM_HI < LIM_LO.
- **REQ-30** A sample changed by the limiter is marked clipped. A sample equal to a limit is not changed and is not marked.
- **REQ-31** The limited sample is written to the output FIFO with its last flag.

## 11. Statistics and interrupts

- **REQ-32** STAT_CLIP counts samples marked clipped, counted once per emitted sample, when the sample enters the output FIFO.
- **REQ-33** STAT_IN counts `s_*` handshakes and STAT_OUT counts `m_*` handshakes.
- **REQ-34** STAT_IN, STAT_OUT and STAT_CLIP saturate at 0xFFFF and do not wrap.
- **REQ-35** PEAK_MAX holds the largest and PEAK_MIN the smallest `m_data` delivered since reset or the last STAT_CLEAR, as signed values.
- **REQ-36** Until the first delivery after a reset or STAT_CLEAR, PEAK_MAX and PEAK_MIN read their reset values.
- **REQ-37** A write to STAT_CLEAR with bit 0 = 1 sets STAT_IN, STAT_OUT and STAT_CLIP to 0 and returns PEAK_MAX and PEAK_MIN to their reset values. If a statistics event occurs in the same cycle, the clear wins.
- **REQ-39** IRQ_STATUS.CLIP is set when a clipped sample enters the output FIFO. IRQ_STATUS.FRAME is set at an `m_*` handshake with `m_last` = 1.
- **REQ-40** IRQ_STATUS is write-1-to-clear. If an event sets a bit in the same cycle as a write clears it, the bit is 1 after that cycle.
- **REQ-41** `irq` = 1 if and only if (IRQ_STATUS AND IRQ_ENABLE) is nonzero. `irq` is a function of the register state only.

## 12. Timing and implementation constraints

- **REQ-42** The design is synchronous to `clk`, uses only `rst_n` as an asynchronous reset, has no latches, and meets the released clock constraint (`flow/constraint.sdc`).

## 13. Compatibility notes

- The module name, port names and port widths in section 2 are fixed.
- The filelist `rtl/filelist.f` lists the source files in compile order, with paths relative to the design root.

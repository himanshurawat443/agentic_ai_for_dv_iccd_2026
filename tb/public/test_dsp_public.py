"""Public testbench for dsp_stream.

These tests pass on the released baseline. They are a starting point, not a
complete verification plan: passing them does not mean the design meets its
specification.
"""

import random

import cocotb

from dsp_tb import (COEF0, CTRL, GAIN, ID, IRQ_ENABLE, IRQ_STATUS, LIM_HI, LIM_LO,
                    NTAPS, OFFSET, PEAK_MAX, ROUND_FLOOR, ROUND_HALF_UP, STAT_CLIP,
                    STAT_IN, STAT_OUT, DspTB, ctrl_word, frame)


async def setup(dut):
    tb = DspTB(dut)
    await tb.start()
    return tb


@cocotb.test()
async def test_reset_and_id(dut):
    """Identifier and reset values of the main registers."""
    tb = await setup(dut)
    assert await tb.read(ID) == 0x44530100
    assert await tb.read(CTRL) == 0x2
    assert await tb.read(GAIN) == 0x0100
    assert await tb.read(LIM_HI) == 0x7FFF
    assert await tb.read(LIM_LO) == 0x8000
    assert await tb.read(NTAPS) == 1
    assert int(dut.m_valid.value) == 0
    assert int(dut.irq.value) == 0


@cocotb.test()
async def test_passthrough(dut):
    """Unity gain, FIR bypassed: samples and frame marks come out unchanged."""
    tb = await setup(dut)
    await tb.write(CTRL, ctrl_word())
    rng = random.Random(3)
    values = [rng.randint(-30000, 30000) for _ in range(40)]
    out = await tb.stream(frame(values), len(values))
    assert out == frame(values)


@cocotb.test()
async def test_backpressure(dut):
    """Order and frame marks hold with random stalls on both sides."""
    tb = await setup(dut)
    await tb.write(CTRL, ctrl_word())
    values = list(range(-50, 50))
    out = await tb.stream(frame(values), len(values), in_stall=0.3, out_stall=0.6)
    assert out == frame(values)


@cocotb.test()
async def test_offset_and_gain(dut):
    """Offset then Q8.8 gain, round half up."""
    tb = await setup(dut)
    await tb.write(CTRL, ctrl_word(rnd=ROUND_HALF_UP))
    await tb.write(OFFSET, 10)
    await tb.write(GAIN, 0x0180)  # 1.5
    values = [10, 11, 12, 13, 110, 1010]
    out = await tb.stream(frame(values), len(values))
    assert [v for v, _ in out] == [0, 2, 3, 5, 150, 1500]


@cocotb.test()
async def test_floor_rounding(dut):
    """Floor rounding of a gain of 0.5 on positive and negative samples."""
    tb = await setup(dut)
    await tb.write(CTRL, ctrl_word(rnd=ROUND_FLOOR))
    await tb.write(GAIN, 0x0080)
    out = await tb.stream(frame([3, 4, -3, -4]), 4)
    assert [v for v, _ in out] == [1, 2, -2, -2]


@cocotb.test()
async def test_positive_saturation(dut):
    """A gain of 2 saturates large positive samples at 32767 and counts them."""
    tb = await setup(dut)
    await tb.write(CTRL, ctrl_word())
    await tb.write(GAIN, 0x0200)
    out = await tb.stream(frame([1000, 20000, 32767]), 3)
    assert [v for v, _ in out] == [2000, 32767, 32767]
    assert await tb.read(STAT_CLIP) == 2


@cocotb.test()
async def test_fir_two_tap_average(dut):
    """Two-tap FIR with coefficients of 0.5."""
    tb = await setup(dut)
    await tb.write(CTRL, ctrl_word(bypass=0))
    await tb.write(NTAPS, 2)
    await tb.write(COEF0 + 0, 0x4000)
    await tb.write(COEF0 + 4, 0x4000)
    out = await tb.stream(frame([100, 200, 300, 400]), 4)
    assert [v for v, _ in out] == [50, 150, 250, 350]


@cocotb.test()
async def test_decimate_full_groups(dut):
    """Decimation by 4 with frames that are a whole number of groups."""
    tb = await setup(dut)
    await tb.write(CTRL, ctrl_word(decim=2))
    values = [10, 20, 30, 40, 100, 100, 100, 100]
    out = await tb.stream(frame(values), 2)
    assert out == [(25, 0), (100, 1)]


@cocotb.test()
async def test_limiter(dut):
    """Limiter window on a positive signal."""
    tb = await setup(dut)
    await tb.write(CTRL, ctrl_word())
    await tb.write(LIM_HI, 500)
    await tb.write(LIM_LO, 100)
    out = await tb.stream(frame([50, 100, 300, 500, 900]), 5)
    assert [v for v, _ in out] == [100, 100, 300, 500, 500]
    assert await tb.read(STAT_CLIP) == 2


@cocotb.test()
async def test_statistics_and_irq(dut):
    """Sample counters, peak hold and the frame interrupt."""
    tb = await setup(dut)
    await tb.write(CTRL, ctrl_word())
    await tb.write(IRQ_ENABLE, 0x2)
    await tb.stream(frame([5, 700, 30]), 3)
    assert await tb.read(STAT_IN) == 3
    assert await tb.read(STAT_OUT) == 3
    assert await tb.read(PEAK_MAX) == 700
    assert int(dut.irq.value) == 1
    assert (await tb.read(IRQ_STATUS)) & 0x2
    await tb.write(IRQ_STATUS, 0x2)
    assert int(dut.irq.value) == 0

"""Testbench helpers for dsp_stream: clock, reset, configuration port and
sample streaming with optional stalls. Inputs change at the falling edge of clk;
outputs are sampled shortly after it, before the next rising edge."""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer

CLK_NS = 10

# Register offsets.
ID, CTRL, OFFSET, GAIN, LIM_HI, LIM_LO, NTAPS, STATUS = (
    0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18, 0x1C)
COEF0 = 0x20
STAT_IN, STAT_OUT, STAT_CLIP, PEAK_MAX, PEAK_MIN, STAT_CLEAR, IRQ_STATUS, IRQ_ENABLE = (
    0x40, 0x44, 0x48, 0x4C, 0x50, 0x54, 0x58, 0x5C)

ROUND_FLOOR, ROUND_HALF_UP, ROUND_HALF_EVEN = 0, 1, 2


def ctrl_word(enable=1, bypass=1, rnd=ROUND_FLOOR, decim=0, clear_on_last=0):
    return enable | bypass << 1 | rnd << 2 | decim << 4 | clear_on_last << 6


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


class DspTB:
    def __init__(self, dut, seed=1):
        self.dut = dut
        self.rng = random.Random(seed)

    async def start(self):
        d = self.dut
        d.rst_n.value = 0
        d.s_valid.value = 0
        d.s_data.value = 0
        d.s_last.value = 0
        d.m_ready.value = 0
        d.cfg_we.value = 0
        d.cfg_addr.value = 0
        d.cfg_wdata.value = 0
        cocotb.start_soon(Clock(d.clk, CLK_NS, unit="ns").start(start_high=False))
        for _ in range(3):
            await FallingEdge(d.clk)
        d.rst_n.value = 1
        await FallingEdge(d.clk)

    async def reset(self):
        d = self.dut
        d.rst_n.value = 0
        await FallingEdge(d.clk)
        await FallingEdge(d.clk)
        d.rst_n.value = 1
        await FallingEdge(d.clk)

    async def write(self, addr, value):
        d = self.dut
        d.cfg_we.value = 1
        d.cfg_addr.value = addr
        d.cfg_wdata.value = value & 0xFFFFFFFF
        await FallingEdge(d.clk)
        d.cfg_we.value = 0

    async def read(self, addr):
        d = self.dut
        d.cfg_we.value = 0
        d.cfg_addr.value = addr
        await Timer(1, unit="ns")
        val = int(d.cfg_rdata.value)
        self.last_err = int(d.cfg_err.value)
        await FallingEdge(d.clk)
        return val

    async def stream(self, samples, expect, in_stall=0.0, out_stall=0.0, timeout=200000):
        """Send (data, last) pairs and collect `expect` (data, last) outputs."""
        d = self.dut
        rng = self.rng
        out = []
        i = 0
        cycles = 0
        pending = False
        while i < len(samples) or len(out) < expect:
            cycles += 1
            assert cycles < timeout, f"timeout: sent {i} of {len(samples)}, got {len(out)} of {expect}"
            if not pending:
                if i < len(samples) and rng.random() >= in_stall:
                    data, last = samples[i]
                    d.s_valid.value = 1
                    d.s_data.value = data & 0xFFFF
                    d.s_last.value = last
                    pending = True
                else:
                    d.s_valid.value = 0
            d.m_ready.value = 1 if rng.random() >= out_stall else 0
            await Timer(1, unit="ns")
            if pending and int(d.s_ready.value):
                pending = False
                i += 1
                sent = True
            else:
                sent = False
            if int(d.m_ready.value) and int(d.m_valid.value):
                out.append((s16(int(d.m_data.value)), int(d.m_last.value)))
            await FallingEdge(d.clk)
            if sent:
                d.s_valid.value = 0
        d.s_valid.value = 0
        d.m_ready.value = 0
        return out

    async def idle(self, cycles=2000):
        """Wait until STATUS.BUSY is 0."""
        for _ in range(cycles):
            if not (await self.read(STATUS)) & 1:
                return
        raise AssertionError("STATUS.BUSY did not clear")


def frame(values):
    """A list of signed samples as (data, last) pairs, last set on the final one."""
    return [(v, 1 if i == len(values) - 1 else 0) for i, v in enumerate(values)]

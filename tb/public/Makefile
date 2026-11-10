# Public testbench for dsp_stream (cocotb + Verilator).
#
#   make                     run all tests on the RTL in ../..
#   make RTL_ROOT=<dir>      run them on another tree that has rtl/filelist.f
#   make COCOTB_TEST_FILTER=<name>   run one test
#
# Requires Verilator 5 and cocotb 2 (both are in the flow image).

RTL_ROOT ?= ../..
RTL_ROOT_ABS := $(abspath $(RTL_ROOT))

SIM ?= verilator
TOPLEVEL_LANG = verilog
TOPLEVEL = dsp_stream
COCOTB_TOPLEVEL = dsp_stream
COCOTB_TEST_MODULES = test_dsp_public
VERILOG_SOURCES = $(addprefix $(RTL_ROOT_ABS)/,$(shell grep -v '^\s*\(//\|#\|$$\)' $(RTL_ROOT_ABS)/rtl/filelist.f))
EXTRA_ARGS += -Wno-fatal --x-assign unique --x-initial unique
SIM_BUILD ?= sim_build_$(notdir $(RTL_ROOT_ABS))

include $(shell cocotb-config --makefiles)/Makefile.sim

# Makefile

SIM = verilator
COMPILE_ARGS = --trace --trace-structs --trace-max-array 65536
TOPLEVEL_LANG = verilog
VERILOG_SOURCES = $(shell pwd)/../rtl/*.v
TOPLEVEL = top
MODULE = riscv_tb
include $(shell cocotb-config --makefiles)/Makefile.sim
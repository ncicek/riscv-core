import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge, RisingEdge
import pandas as pd 

def add_inst(rs1, rs2, rd):
    return rs2<<20 | rs1<<15 | rd<<7 | 0b0110011

def load_inst(base, offset, rd):
    return offset<<20 | base<<15 | 0b010<<12 | rd<<7 | 0b0000011

def program_imem(mem_array):
    mem_array[0] = load_inst(0, 10, 5)
    mem_array[1] = add_inst(1,2,3)

@cocotb.test()
async def riscv_tb(dut):
    total_cycles = 100

    clock = Clock(dut.i_clk, 1, units="ns")  # Create a 10us period clock on port clk
    cocotb.fork(clock.start())  # Start the clock

    await FallingEdge(dut.i_clk)  # Synchronize with the clock
    dut.i_reset <= 1  # Assign the random value val to the input port d
    program_imem(dut.i_mem.mem_array)
    await Timer(4, "ns") #skip the undefined state
    dut.i_reset <= 0

    for i in range(total_cycles):
        await RisingEdge(dut.i_clk)

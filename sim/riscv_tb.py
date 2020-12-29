import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge, RisingEdge
import pandas as pd 

def program_imem(mem_array):
    for i in range(100):
        mem_array[i] <= 0xFFFFFFFF % (i+1);

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

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

def instruction_decode(i):
    #Based on "RV32I Reference Card" in https://github.com/johnwinans/rvalp/releases
    op = i & 0b1111111
    
    if op == 0b0110111:
        inst = 'lui'
        type = 'u'        
    
    elif op == 0b0010111:
        inst = 'auipc'
        type = 'u'
    
    elif op == 0b1101111:
        inst = 'jal'
        type = 'j'
    
    elif op == 0b1100111:
        inst = 'jalr'
        type = 'i'
    
    elif op == 0b1100011:
        type = 'b'
        funct3 = (i >> 12) & 0b111
        if funct3 == 0b000:
            inst = 'beq'
        elif funct3 == 0b001:
            inst = 'bne'
        elif funct3 == 0b100:
            inst = 'blt'
        elif funct3 == 0b101:
            inst = 'bge'
        elif funct3 == 0b110:
            inst = 'bltu'
        elif funct3 == 0b111:
            inst = 'bgeu'
        else:
            raise 'error'
    
    elif op == 0b0000011:
        type = 'i'
        funct3 = (i >> 12) & 0b111
        if funct3 == 0b000:
            inst = 'lb'
        elif funct3 == 0b001:
            inst = 'lh'
        elif funct3 == 0b010:
            inst = 'lw'
        elif funct3 == 0b100:
            inst = 'lbu'
        elif funct3 == 0b101:
            inst = 'lhu'
        else:    
            raise 'error'
    
    elif op == 0b0100011:
        type = 's'
        funct3 = (i >> 12) & 0b111
        if funct3 == 0b000:
            inst = 'sb'
        elif funct3 == 0b001:
            inst = 'sh'
        elif funct3 == 0b010:
            inst = 'sw'
        else:    
            raise 'error'
    
    elif op == 0b0010011:
        type = 'i'
        funct3 = (i >> 12) & 0b111
        funct7 = (i >> 25)
        
        if funct3 == 0b000:
            inst = 'addi'
        elif funct3 == 0b010:
            inst = 'slti'
        elif funct3 == 0b011:
            inst = 'sltu'
        elif funct3 == 0b100:
            inst = 'xori'
        elif funct3 == 0b110:
            inst = 'ori'
        elif funct3 == 0b111:
            inst = 'andi'
        
        elif funct3 == 0b001 and funct7 == 0b0000000:
            inst = 'slli'
        elif funct3 == 0b101 and funct7 == 0b0000000:
            inst = 'srli'
        elif funct3 == 0b101 and funct7 == 0b0100000:
            inst = 'srai'
        else:    
            raise 'error'

    elif op == 0b0110011:
        type = 'r'
        funct3 = (i >> 12) & 0b111
        funct7 = (i >> 25)

        if funct3 == 0b000 and funct7 == 0b0000000:
            inst = 'add'
        elif funct3 == 0b000 and funct7 == 0b0100000:
            inst = 'sub'
        elif funct3 == 0b001 and funct7 == 0b0000000:
            inst = 'sll'
        elif funct3 == 0b010 and funct7 == 0b0000000:
            inst = 'slt'
        elif funct3 == 0b011 and funct7 == 0b0000000:
            inst = 'sltu'
        elif funct3 == 0b100 and funct7 == 0b0000000:
            inst = 'xor'
        elif funct3 == 0b101 and funct7 == 0b0000000:
            inst = 'srl'
        elif funct3 == 0b101 and funct7 == 0b0100000:
            inst = 'sra'
        elif funct3 == 0b110 and funct7 == 0b0000000:
            inst = 'or'
        elif funct3 == 0b111 and funct7 == 0b0000000:
            inst = 'and'
        else:
            raise 'error'
    else:
        print(op)
        raise "error"

    #operand field decode
    if type == 'r':
        rd = (i >> 7) & 0b11111
        funct3 = (i >> 12) & 0b111
        rs1 = (i >> 15) & 0b11111
        rs2 = (i >> 20) & 0b11111
        funct7 = (i >> 25)
        print("Instruction: ", inst, "   ", "Type: R", "   ", "Rd: ", rd, "   ", "Rs1: ", rs1, "   ", "Rs2: ", rs2)

    elif type == 'i':
        rd = (i >> 7) & 0b11111
        funct3 = (i >> 12) & 0b111
        rs1 = (i >> 15) & 0b11111
        imm = (i >> 20) & 0b111111111111
        if inst == 'addi' and rd == 0 and rs1 == 0 and imm == 0:
            inst = 'nop'
        print("Instruction: ", inst, "   ", "Type: I", "   ", "Rd: ", rd, "   ", "Rs1: ", rs1, "   ", "Imm: ", imm)

    elif type == 's':
        imm4_0 = (i >> 7) & 0b11111
        funct3 = (i >> 12) & 0b111
        rs1 = (i >> 15) & 0b11111
        rs2 = (i >> 20) & 0b11111
        imm_11_5 = (i >> 25)
        imm = imm4_0 | (imm_11_5 << 5)
        print("Instruction: ", inst, "   ", "Type: S", "   ", "Rs1: ", rs1, "   ", "Rs2: ", rs2, "   ", "Imm[11:0]: ", imm)

    elif type == 'u':
        rd = (i >> 7) & 0b11111
        imm31_12 = i >> 12
        print("Instruction: ", inst, "   ", "Type: U", "   ", "Rd: ", rd, "   ", "Imm[31:12]: ", imm31_12)
    
    else:
        raise "error"

    
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
        #dump each instruction in the pipeline
        print(dut.pc.value.integer)
        instruction_decode(dut.if_id_pipeline_instruction.value.integer)
        instruction_decode(dut.id_ex_pipeline_instruction.value.integer)
        instruction_decode(dut.ex_mem_pipeline_instruction.value.integer)
        instruction_decode(dut.mem_wb_pipeline_instruction.value.integer)
        

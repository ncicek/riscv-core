import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge, RisingEdge
from random import randint
from random import sample

rand_itrs = 100

NOP = 0b0010011

def add_inst(rs1, rs2, rd):
    assert rs1 < 32
    assert rs2 < 32
    assert rd < 32
    return rs2<<20 | rs1<<15 | rd<<7 | 0b0110011

def sub_inst(rs1, rs2, rd):
    assert rs1 < 32
    assert rs2 < 32
    assert rd < 32
    return 0b0100000<<25 | rs2<<20 | rs1<<15 | rd<<7 | 0b0110011

def and_inst(rs1, rs2, rd):
    assert rs1 < 32
    assert rs2 < 32
    assert rd < 32
    return rs2<<20 | rs1<<15 | 0b111<<12 | rd<<7 | 0b0110011

def or_inst(rs1, rs2, rd):
    assert rs1 < 32
    assert rs2 < 32
    assert rd < 32
    return rs2<<20 | rs1<<15 | 0b110<<12 | rd<<7 | 0b0110011

def load_inst(load_inst, offset_address, destination_register):
    assert load_inst & 0b11111 == load_inst
    assert destination_register & 0b11111 == destination_register
    assert offset_address & 0b111111111111 == offset_address
    return offset_address<<20 | load_inst<<15 | 0b010<<12 | destination_register<<7 | 0b0000011

#memories are indexed in 4-byte chunks. ie idx0 is the first 32 bits, idx1 is the second 32 bits
def program_imem(dut):
    mem_array = dut.i_mem.mem_array

    #fill it with nops first
    for i in range(len(mem_array)):
        mem_array[i] = NOP

    mem_array[0] = load_inst(0, 0, 1)
    mem_array[1] = load_inst(0, 4, 2)
    mem_array[2] = add_inst(1,2,3)

def program_dmem(dut):
    mem_array = dut.d_mem.mem_array
    mem_array[0] = 100
    mem_array[1] = 200

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
        return {'inst': inst, 'type': type, 'rd':rd, 'rs1':rs1, 'rs2':rs2}
        #print("Instruction: ", inst, "   ", "Type: R", "   ", "Rd: ", rd, "   ", "Rs1: ", rs1, "   ", "Rs2: ", rs2)

    elif type == 'i':
        rd = (i >> 7) & 0b11111
        funct3 = (i >> 12) & 0b111
        rs1 = (i >> 15) & 0b11111
        imm = (i >> 20) & 0b111111111111
        if inst == 'addi' and rd == 0 and rs1 == 0 and imm == 0:
            inst = 'nop'
        return {'inst': inst, 'type': type, 'rd':rd, 'rs1':rs1, 'imm':imm}
        #print("Instruction: ", inst, "   ", "Type: I", "   ", "Rd: ", rd, "   ", "Rs1: ", rs1, "   ", "Imm: ", imm)

    elif type == 's':
        imm4_0 = (i >> 7) & 0b11111
        funct3 = (i >> 12) & 0b111
        rs1 = (i >> 15) & 0b11111
        rs2 = (i >> 20) & 0b11111
        imm_11_5 = (i >> 25)
        imm = imm4_0 | (imm_11_5 << 5)
        #print("Instruction: ", inst, "   ", "Type: S", "   ", "Rs1: ", rs1, "   ", "Rs2: ", rs2, "   ", "Imm[11:0]: ", imm)
        return {'inst': inst, 'type': type, 'rs1':rs1, 'rs2':rs2, 'imm_11_0':imm}

    elif type == 'u':
        rd = (i >> 7) & 0b11111
        imm31_12 = i >> 12
        #print("Instruction: ", inst, "   ", "Type: U", "   ", "Rd: ", rd, "   ", "Imm[31:12]: ", imm31_12)
        return {'inst': inst, 'type': type, 'rd':rd, 'imm_31_12':imm31_12}

    else:
        raise "error"

    
@cocotb.test()
async def riscv_tb(dut):
    total_cycles = 10

    clock = Clock(dut.i_clk, 1, units="ns")  # Create a 10us period clock on port clk
    cocotb.fork(clock.start())  # Start the clock

    dut.i_reset <= 1  # Assign the random value val to the input port d
    program_imem(dut)
    program_dmem(dut)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    #await Timer(2, "ns") #skip the undefined state
    dut.i_reset <= 0
    #await RisingEdge(dut.i_clk) #skip the first idle cycle
    for i in range(total_cycles):
        await RisingEdge(dut.i_clk)
        #dump each instruction in the pipeline

        id_inst = instruction_decode(dut.if_id_pipeline_instruction.value.integer)
        id_pc = dut.if_id_pipeline_pc.value.integer

        ex_inst = instruction_decode(dut.id_ex_pipeline_instruction.value.integer)

        mem_inst = instruction_decode(dut.ex_mem_pipeline_instruction.value.integer)

        wb_inst = instruction_decode(dut.mem_wb_pipeline_instruction.value.integer)
        
        registers = [dut.register_file_i.x[i].value.integer for i in range(32)]

        print("ID PC: ", id_pc)
        print("ID STAGE: ", id_inst)
        print("EX STAGE: ", ex_inst)
        print("MEM STAGE: ", mem_inst)
        print("WB_STAGE: ", wb_inst)
        print (registers)
        print("--------------------------------------")
        

class TB():
    def __init__(self, dut):
        self.dut = dut
        clock = Clock(dut.i_clk, 1, units="ns")  # Create a 10us period clock on port clk
        cocotb.fork(clock.start())  # Start the clock
    
    def dmem_write(self, addr, data):
        assert addr % 4 == 0 #byte aligned
        addr_index = addr // 4
        assert data & 0xFFFFFFFF == data
        self.dut.d_mem.mem_array[addr_index] = data

    def imem_write(self, addr, data):
        assert addr % 4 == 0 #byte aligned
        addr_index = addr // 4
        assert data & 0xFFFFFFFF == data
        self.dut.i_mem.mem_array[addr_index] = data
        #print("writing data: ", hex(data), "to addr: ",hex(addr))

    def register_file_read(self, register):
        assert register & 0b11111 == register
        return self.dut.register_file_i.x[register].value

    async def reset(self):
        self.dut.i_reset <= 1
        await self.wait_cycles(2)
        self.dut.i_reset <= 0

    async def wait_cycles(self, n):
        for _ in range(n):
            await RisingEdge(self.dut.i_clk)
    
    async def assert_reset(self):
        self.dut.i_reset <= 1
        await self.wait_cycles(1)

    def deassert_reset(self):
        self.dut.i_reset <= 0

@cocotb.test()
async def add(dut):
    tb = TB(dut)

    for i in range(rand_itrs):
        await tb.assert_reset()
        base_register = 0
        destination_register = sample(range(1, 31), 3)
        offset_address = [i * 4 for i in sample(range(0, 63), 2)]
        #print(offset_address)
        tb.imem_write(0, load_inst(base_register, offset_address[0], destination_register[0]))
        tb.imem_write(4, load_inst(base_register, offset_address[1], destination_register[1]))
        tb.imem_write(8, add_inst(destination_register[0], destination_register[1], destination_register[2]))

        dmem_value = [randint(0, 0xfffffff), randint(0, 0xfffffff)]
        tb.dmem_write(offset_address[0], dmem_value[0])
        tb.dmem_write(offset_address[1], dmem_value[1])

       
        tb.deassert_reset()
        await tb.wait_cycles(10)
        #print(offset_address[0], hex(dmem_value[0]), offset_address[1], hex(dmem_value[1]), hex(tb.register_file_read(destination_register[2])))
        assert tb.register_file_read(destination_register[2]) == (dmem_value[0] + dmem_value[1]) & 0xFFFFFFFF


@cocotb.test()
async def sub(dut):
    tb = TB(dut)

    for i in range(rand_itrs):
        await tb.assert_reset()
        base_register = 0
        destination_register = sample(range(1, 31), 3)
        offset_address = [i * 4 for i in sample(range(0, 63), 2)]
        #print(offset_address)
        tb.imem_write(0, load_inst(base_register, offset_address[0], destination_register[0]))
        tb.imem_write(4, load_inst(base_register, offset_address[1], destination_register[1]))
        tb.imem_write(8, sub_inst(destination_register[0], destination_register[1], destination_register[2]))

        dmem_value = [randint(0, 0xfffffff), randint(0, 0xfffffff)]
        tb.dmem_write(offset_address[0], dmem_value[0])
        tb.dmem_write(offset_address[1], dmem_value[1])

       
        tb.deassert_reset()
        await tb.wait_cycles(10)
        #print(offset_address[0], hex(dmem_value[0]), offset_address[1], hex(dmem_value[1]), hex(tb.register_file_read(destination_register[2])))
        assert tb.register_file_read(destination_register[2]) == (dmem_value[0] - dmem_value[1]) & 0xFFFFFFFF

@cocotb.test()
async def and_i(dut):
    tb = TB(dut)

    for i in range(rand_itrs):
        await tb.assert_reset()
        base_register = 0
        destination_register = sample(range(1, 31), 3)
        offset_address = [i * 4 for i in sample(range(0, 63), 2)]
        #print(offset_address)
        tb.imem_write(0, load_inst(base_register, offset_address[0], destination_register[0]))
        tb.imem_write(4, load_inst(base_register, offset_address[1], destination_register[1]))
        tb.imem_write(8, and_inst(destination_register[0], destination_register[1], destination_register[2]))
        #print(and_inst(destination_register[0], destination_register[1], destination_register[2]))


        dmem_value = [randint(0, 0xfffffff), randint(0, 0xfffffff)]
        tb.dmem_write(offset_address[0], dmem_value[0])
        tb.dmem_write(offset_address[1], dmem_value[1])

       
        tb.deassert_reset()
        await tb.wait_cycles(10)
        #print(offset_address[0], hex(dmem_value[0]), offset_address[1], hex(dmem_value[1]), hex(tb.register_file_read(destination_register[2])))
        assert tb.register_file_read(destination_register[2]) == (dmem_value[0] & dmem_value[1])


@cocotb.test()
async def or_i(dut):
    tb = TB(dut)

    for i in range(rand_itrs):
        await tb.assert_reset()
        base_register = 0
        destination_register = sample(range(1, 31), 3)
        offset_address = [i * 4 for i in sample(range(0, 63), 2)]
        #print(offset_address)
        tb.imem_write(0, load_inst(base_register, offset_address[0], destination_register[0]))
        tb.imem_write(4, load_inst(base_register, offset_address[1], destination_register[1]))
        tb.imem_write(8, or_inst(destination_register[0], destination_register[1], destination_register[2]))

        dmem_value = [randint(0, 0xfffffff), randint(0, 0xfffffff)]
        tb.dmem_write(offset_address[0], dmem_value[0])
        tb.dmem_write(offset_address[1], dmem_value[1])

       
        tb.deassert_reset()
        await tb.wait_cycles(10)
        #print(offset_address[0], hex(dmem_value[0]), offset_address[1], hex(dmem_value[1]), hex(tb.register_file_read(destination_register[2])))
        assert tb.register_file_read(destination_register[2]) == (dmem_value[0] | dmem_value[1])

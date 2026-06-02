import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


RET = 0xF000


async def reset_dut(dut):

    dut.start.value = 0
    dut.reset.value = 1

    dut.block_id.value = 0
    dut.thread_count.value = 4

    dut.program_mem_read_ready.value = 0
    dut.program_mem_read_data.value = 0

    dut.data_mem_read_ready.value = 0
    dut.data_mem_write_ready.value = 0

    for i in range(4):
        dut.data_mem_read_data[i].value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.reset.value = 0

    await RisingEdge(dut.clk)


async def run_program(dut, program):

    dut.start.value = 1

    timeout = 500

    while timeout > 0:

        await RisingEdge(dut.clk)

        if int(dut.program_mem_read_valid.value):

            pc = int(dut.program_mem_read_address.value)

            if pc < len(program):
                instr = program[pc]
            else:
                instr = RET

            dut.program_mem_read_data.value = instr
            dut.program_mem_read_ready.value = 1

            await RisingEdge(dut.clk)

            dut.program_mem_read_ready.value = 0

        if int(dut.done.value):
            return

        timeout -= 1

    raise AssertionError("Program timeout")


def read_reg(dut, reg_idx):

    return int(
        dut.g_thread[0]
           .register_instance
           .register_file[reg_idx]
           .value
    )

def read_nzp(dut):

    return int(
        dut.g_thread[0]
           .pc_instance
           .nzp
           .value
    )

@cocotb.test()
async def test_cmp_program(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    await reset_dut(dut)

    program = [
        0x910A,   # CONST R1,10
        0x9214,   # CONST R2,20
        0x2012,   # CMP R1,R2
        RET,
    ]

    await run_program(dut, program)

    #
    # 10 < 20
    #
    # Expected:
    # N=1 Z=0 P=0
    #

    assert read_nzp(dut) == 0b001

@cocotb.test()
async def test_const_program(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    await reset_dut(dut)

    program = [
        0x9037,   # CONST R0,55
        RET,
    ]

    await run_program(dut, program)

    assert read_reg(dut, 0) == 55


@cocotb.test()
async def test_add_program(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    await reset_dut(dut)

    program = [
        0x910A,   # CONST R1,10
        0x9214,   # CONST R2,20
        0x3012,   # ADD R0,R1,R2
        RET,
    ]

    await run_program(dut, program)

    assert read_reg(dut, 0) == 30


@cocotb.test()
async def test_sub_program(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    await reset_dut(dut)

    program = [
        0x9132,   # CONST R1,50
        0x9214,   # CONST R2,20
        0x4012,   # SUB R0,R1,R2
        RET,
    ]

    await run_program(dut, program)

    assert read_reg(dut, 0) == 30


@cocotb.test()
async def test_mul_program(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    await reset_dut(dut)

    program = [
        0x910A,   # CONST R1,10
        0x9214,   # CONST R2,20
        0x5012,   # MUL R0,R1,R2
        RET,
    ]

    await run_program(dut, program)

    assert read_reg(dut, 0) == 200


@cocotb.test()
async def test_div_program(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    await reset_dut(dut)

    program = [
        0x9114,   # CONST R1,20
        0x9204,   # CONST R2,4
        0x6012,   # DIV R0,R1,R2
        RET,
    ]

    await run_program(dut, program)

    assert read_reg(dut, 0) == 5
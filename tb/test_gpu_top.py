import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


RET = 0xF000


async def reset_dut(dut):

    dut.start.value = 0
    dut.reset.value = 1

    dut.device_control_write_enable.value = 0
    dut.device_control_data.value = 0

    dut.program_mem_read_ready.value = 0

    for i in range(1):
        dut.program_mem_read_data[i].value = 0

    dut.data_mem_read_ready.value = 0
    dut.data_mem_write_ready.value = 0

    for i in range(4):
        dut.data_mem_read_data[i].value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.reset.value = 0

    await RisingEdge(dut.clk)


async def configure_threads(dut, count):

    dut.device_control_data.value = count
    dut.device_control_write_enable.value = 1

    await RisingEdge(dut.clk)

    dut.device_control_write_enable.value = 0


async def run_program(dut, program):

    dut.start.value = 1

    timeout = 5000

    while timeout > 0:

        await RisingEdge(dut.clk)

        #
        # Program memory
        #

        valid = int(dut.program_mem_read_valid.value)

        if valid:

            for ch in range(1):

                if ((valid >> ch) & 1):

                    pc = int(
                        dut.program_mem_read_address[ch].value
                    )

                    if pc < len(program):
                        instr = program[pc]
                    else:
                        instr = RET

                    dut.program_mem_read_data[ch].value = instr

            dut.program_mem_read_ready.value = valid

            await RisingEdge(dut.clk)

            dut.program_mem_read_ready.value = 0

        #
        # Data memory reads
        #

        read_valid = int(
            dut.data_mem_read_valid.value
        )

        if read_valid:

            for ch in range(4):

                if ((read_valid >> ch) & 1):

                    addr = int(
                        dut.data_mem_read_address[ch].value
                    )

                    if addr == 10:
                        dut.data_mem_read_data[ch].value = 77
                    else:
                        dut.data_mem_read_data[ch].value = 0

            dut.data_mem_read_ready.value = read_valid

            await RisingEdge(dut.clk)

            dut.data_mem_read_ready.value = 0

        #
        # Data memory writes
        #

        write_valid = int(
            dut.data_mem_write_valid.value
        )

        if write_valid:

            dut.data_mem_write_ready.value = write_valid

            await RisingEdge(dut.clk)

            dut.data_mem_write_ready.value = 0

        if int(dut.done.value):
            return

        timeout -= 1

    raise AssertionError("GPU timeout")

@cocotb.test()
async def test_gpu_const_program(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    await reset_dut(dut)

    await configure_threads(
        dut,
        4
    )

    program = [
        0x9037,   # CONST R0,55
        RET,
    ]

    await run_program(
        dut,
        program
    )

    assert int(dut.done.value) == 1
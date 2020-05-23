from memory_core.memory_core import gen_memory_core, Mode
from memory_core.memory_core_magma import MemCore
import glob
import tempfile
import shutil
import fault
import random
import magma
from gemstone.common.testers import ResetTester
from gemstone.common.testers import BasicTester
import pytest
from gemstone.generator import Const


def make_memory_core():
    mem_core = MemCore()
    mem_circ = mem_core.circuit()
    
    tester = MemoryCoreTester(mem_circ, mem_circ.clk, mem_circ.reset)
    tester.poke(mem_circ.clk, 0)
    tester.poke(mem_circ.reset, 0)
    tester.step(1)
    tester.poke(mem_circ.reset, 1)
    tester.step(1)
    tester.reset()
    return [mem_circ, tester, mem_core]


class MemoryCoreTester(BasicTester):

    def configure(self, addr, data, feature):
        self.poke(self.clock, 0)
        self.poke(self.reset_port, 0)
        if(feature == 0):
            exec(f"self.poke(self._circuit.config.config_addr, addr)")
            exec(f"self.poke(self._circuit.config.config_data, data)")
            exec(f"self.poke(self._circuit.config.write, 1)")
            self.step(1)
            exec(f"self.poke(self._circuit.config.write, 0)")
            exec(f"self.poke(self._circuit.config.config_data, 0)")
        else:
            exec(f"self.poke(self._circuit.config_{feature}.config_addr, addr)")
            exec(f"self.poke(self._circuit.config_{feature}.config_data, data)")
            exec(f"self.poke(self._circuit.config_{feature}.write, 1)")
            self.step(1)
            exec(f"self.poke(self._circuit.config_{feature}.write, 0)")
            exec(f"self.poke(self._circuit.config_{feature}.config_data, 0)")


def test_multiple_output_ports():
    # Regular Bootstrap
    [Mem, tester, MCore] = make_memory_core()
    
    tile_en = 1
    depth = 1024
    chunk = 128
    range_0 = 2
    range_1 = 256
    stride_0 = 0
    stride_1 = 1
    dimensionality = 2
    starting_addr = 0
    startup_delay = 4
    mode = Mode.DB
    iter_cnt = range_0 * range_1
    
    config_data = []

    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_input_port_0"), 0, 0))
    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_output_port_0"), 1, 0))
    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_coarse_output_port_0"), 1, 0))
    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_read_depth_0"), 3 * chunk * 4, 0))
    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_write_depth_wo_0"), 256 * 4, 0))
    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_write_depth_ss_0"), 256 * 4, 0))
    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_coarse_read_depth_0"), int(3 * chunk), 0)
    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_coarse_write_depth_wo_0"(, 256, 0))
    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_coarse_write_depth_ss_0"), 256, 0))

    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_dimensionality"), 2, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_ranges_0"), 256, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_ranges_1"), 100, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_ranges_2"), 0, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_ranges_3"), 0, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_starting_addr"), 0, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_strides_0"), 1, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_strides_1"), 256, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_strides_2"), 0, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_strides_3"), 0, 0))
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_strides_4"), 0, 0)
    config_data.append((MCore.get_reg_index("strg_ub_input_addr_ctrl_address_gen_0_strides_5"), 0, 0)

    config_data.append((MCore.get_reg_index("strg_ub_output_addr_ctrl_address_gen_0_dimensionality"), 3, 0))
    config_data.append((MCore.get_reg_index("strg_ub_output_addr_ctrl_address_gen_0_ranges_0"), 128, 0))
    config_data.append((MCore.get_reg_index("strg_ub_output_addr_ctrl_address_gen_0_ranges_1"), 3, 0))
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(
    config_data.append((MCore.get_reg_index(


    config_data.append((MCore.get_reg_index("strg_ub_app_ctrl_output_port_0"), 0, 0))
    config_data.append((MCore.get_reg_index("tile_en"), tile_en, 0))
    config_data.append((MCore.get_reg_index("mode"), mode.value, 0))
    
    # Configure
    for addr, data, feat in config_data:
        tester.configure(addr, data, feat)

    with tempfile.TemporaryDirectory() as tempdir:
        tempdir="dump"
        for genesis_verilog in glob.glob("genesis_verif/*.*"):
            shutil.copy(genesis_verilog, tempdir)
        tester.compile_and_run(directory=tempdir,
                               magma_output="coreir-verilog",
                               target="verilator",
                               flags=["-Wno-fatal", "--trace"])


def test_fifo_arb(depth=50):
    [Mem, tester, MCore] = make_memory_core()
    mode = Mode.FIFO
    tile_en = 1
    config_data = []
    config_data.append((MCore.get_reg_index("depth"), depth, 0))
    config_data.append((MCore.get_reg_index("tile_en"), tile_en, 0))
    config_data.append((MCore.get_reg_index("mode"), mode.value, 0))
    # Configure the functional model in much the same way as the actual device
    tester.functional_model.config_fifo(depth)
    for addr, data, feat in config_data:
        tester.configure(addr, data, feat)

    for i in range(10):
        for i in range(depth):
            tester.write(random.randint(1, 101))
        for i in range(depth):
            tester.read()

    with tempfile.TemporaryDirectory() as tempdir:
        for genesis_verilog in glob.glob("genesis_verif/*.*"):
            shutil.copy(genesis_verilog, tempdir)
        tester.compile_and_run(directory=tempdir,
                               magma_output="coreir-verilog",
                               target="verilator",
                               flags=["-Wno-fatal"])


def test_general_fifo(depth=50, read_cadence=6):
    [Mem, tester, MCore] = make_memory_core()
    mode = Mode.FIFO
    tile_en = 1
    config_data = []
    config_data.append((MCore.get_reg_index("depth"), depth, 0))
    config_data.append((MCore.get_reg_index("tile_en"), tile_en, 0))
    config_data.append((MCore.get_reg_index("mode"), mode.value, 0))
    # Configure the functional model in much the same way as the actual device
    tester.functional_model.config_fifo(depth)
    for addr, data, feat in config_data:
        tester.configure(addr, data, feat)
    # do depth writes, then read
    for i in range(depth):
        if(i % read_cadence == 0):
            tester.read_and_write(i + 1)
        else:
            tester.write(i + 1)

    with tempfile.TemporaryDirectory() as tempdir:
        for genesis_verilog in glob.glob("genesis_verif/*.*"):
            shutil.copy(genesis_verilog, tempdir)
        tester.compile_and_run(directory=tempdir,
                               magma_output="coreir-verilog",
                               target="verilator",
                               flags=["-Wno-fatal"])


def test_db_arbitrary_rw_addr():
    [Mem, tester, MCore] = make_memory_core()
    memory_size = 1024
    ranges = [1, 1, 1, 1, 1, 1]
    strides = [1, 1, 1, 1, 1, 1]
    tester.functional_model.config_db(memory_size, ranges, strides,
                                      0, 1, 3, 1)

    arbitrary_addr = 1
    mode = Mode.DB
    tile_en = 1
    depth = 130
    config_data = []
    config_data.append((MCore.get_reg_index("depth"), depth, 0))
    config_data.append((MCore.get_reg_index("tile_en"), tile_en, 0))
    config_data.append((MCore.get_reg_index("mode"), mode.value, 0))
    config_data.append((MCore.get_reg_index("arbitrary_addr"),
                        arbitrary_addr, 0))

    for addr, data, feat in config_data:
        tester.configure(addr, data, feat)

    for i in range(100):
        tester.write((i + 1))

    tester.poke(Mem.clk, 0)
    tester.poke(Mem.switch_db, 1)
    tester.eval()
    tester.poke(Mem.clk, 1)
    tester.eval()
    tester.poke(Mem.clk, 0)
    tester.poke(Mem.switch_db, 0)
    tester.functional_model.switch()

    for i in range(100):
        randaddr = random.randint(0, 99)
        tester.read_and_write(i + 1, randaddr)

    tester.poke(Mem.clk, 0)
    tester.poke(Mem.switch_db, 1)
    tester.functional_model.data_out = fault.AnyValue
    tester.eval()
    tester.poke(Mem.clk, 1)
    tester.eval()
    tester.poke(Mem.clk, 0)
    tester.poke(Mem.switch_db, 0)
    tester.functional_model.switch()
    tester.functional_model.data_out = fault.AnyValue

    for i in range(100):
        randaddr = random.randint(0, 99)
        tester.read(randaddr)

    with tempfile.TemporaryDirectory() as tempdir:
        for genesis_verilog in glob.glob("genesis_verif/*.*"):
            shutil.copy(genesis_verilog, tempdir)
        tester.compile_and_run(directory=tempdir,
                               magma_output="coreir-verilog",
                               target="verilator",
                               flags=["-Wno-fatal"])


def test_db_arbitrary_addr():
    [Mem, tester, MCore] = make_memory_core()
    memory_size = 1024
    ranges = [1, 1, 1, 1, 1, 1]
    strides = [1, 1, 1, 1, 1, 1]
    tester.functional_model.config_db(memory_size, ranges, strides,
                                      0, 1, 3, 1)

    arbitrary_addr = 1
    mode = Mode.DB
    tile_en = 1
    depth = 130

    config_data = []
    config_data.append((MCore.get_reg_index("depth"), depth, 0))
    config_data.append((MCore.get_reg_index("tile_en"), tile_en, 0))
    config_data.append((MCore.get_reg_index("mode"), mode.value, 0))
    config_data.append((MCore.get_reg_index("arbitrary_addr"),
                        arbitrary_addr, 0))
    for addr, data, feat in config_data:
        tester.configure(addr, data, feat)

    for i in range(100):
        tester.write((i + 1))

    tester.poke(Mem.clk, 0)
    tester.poke(Mem.switch_db, 1)
    tester.eval()
    tester.poke(Mem.clk, 1)
    tester.eval()
    tester.poke(Mem.clk, 0)
    tester.poke(Mem.switch_db, 0)
    tester.functional_model.switch()
    tester.functional_model.data_out = fault.AnyValue

    for i in range(100):
        randaddr = random.randint(0, 99)
        tester.read(randaddr)

    for i in range(100):
        tester.write((i + 1))

    tester.poke(Mem.clk, 0)
    tester.poke(Mem.switch_db, 1)
    tester.eval()
    tester.poke(Mem.clk, 1)
    tester.eval()
    tester.poke(Mem.clk, 0)
    tester.poke(Mem.switch_db, 0)
    tester.functional_model.switch()

    for i in range(100):
        randaddr = random.randint(0, 99)
        tester.read(randaddr)

    with tempfile.TemporaryDirectory() as tempdir:
        for genesis_verilog in glob.glob("genesis_verif/*.*"):
            shutil.copy(genesis_verilog, tempdir)
        tester.compile_and_run(directory=tempdir,
                               magma_output="coreir-verilog",
                               target="verilator",
                               flags=["-Wno-fatal"])


def test_db_gen1():
    db_gen(1, 3, 9, 0, 0, 0,
           3, 3, 3, 1, 1, 1,
           3, 27)


def test_db_gen2():
    db_gen(1, 3, 1, 3, 9, 0,
           2, 2, 2, 2, 3, 1,
           5, 27)


def db_gen(stride_0, stride_1, stride_2, stride_3, stride_4, stride_5,
           range_0, range_1, range_2, range_3, range_4, range_5,
           dimensionality, input_size,
           starting_addr=0,
           arbitrary_addr=0):

    [Mem, tester, MCore] = make_memory_core()
    iter_cnt = range_0 * range_1 * range_2 * range_3 * range_4 * range_5
    depth = input_size
    # Assumes all ranges are 1 minimally
    ranges = [range_0, range_1, range_2, range_3, range_4, range_5]
    strides = [stride_0, stride_1, stride_2, stride_3, stride_4, stride_5]
    tester.functional_model.config_db(depth, ranges, strides,
                                      starting_addr,
                                      0, dimensionality)

    mode = Mode.DB
    tile_en = 1
    config_data = []
    config_data.append((MCore.get_reg_index("depth"), depth, 0))
    config_data.append((MCore.get_reg_index("tile_en"), tile_en, 0))
    config_data.append((MCore.get_reg_index("mode"), mode.value, 0))
    config_data.append((MCore.get_reg_index("arbitrary_addr"),
                        arbitrary_addr, 0))
    config_data.append((MCore.get_reg_index("starting_addr"),
                        starting_addr, 0))
    config_data.append((MCore.get_reg_index("dimensionality"),
                        dimensionality, 0))
    config_data.append((MCore.get_reg_index("stride_0"), stride_0, 0))
    config_data.append((MCore.get_reg_index("stride_1"), stride_1, 0))
    config_data.append((MCore.get_reg_index("stride_2"), stride_2, 0))
    config_data.append((MCore.get_reg_index("stride_3"), stride_3, 0))
    config_data.append((MCore.get_reg_index("stride_4"), stride_4, 0))
    config_data.append((MCore.get_reg_index("stride_5"), stride_5, 0))
    config_data.append((MCore.get_reg_index("range_0"), range_0, 0))
    config_data.append((MCore.get_reg_index("range_1"), range_1, 0))
    config_data.append((MCore.get_reg_index("range_2"), range_2, 0))
    config_data.append((MCore.get_reg_index("range_3"), range_3, 0))
    config_data.append((MCore.get_reg_index("range_4"), range_4, 0))
    config_data.append((MCore.get_reg_index("range_5"), range_5, 0))
    config_data.append((MCore.get_reg_index("iter_cnt"), iter_cnt, 0))
    for addr, data, feat in config_data:
        tester.configure(addr, data, feat)

    for i in range(depth):
        tester.write(i + 1)
    for i in range(depth):
        tester.write_and_observe(2 * i + 1)
    for i in range(depth, iter_cnt):
        tester.observe(2 * i + 1)
    for i in range(depth):
        tester.write_and_observe(3 * i + 1)

    with tempfile.TemporaryDirectory() as tempdir:
        for genesis_verilog in glob.glob("genesis_verif/*.*"):
            shutil.copy(genesis_verilog, tempdir)
        tester.compile_and_run(directory=tempdir,
                               magma_output="coreir-verilog",
                               target="verilator",
                               flags=["-Wno-fatal"])


@pytest.mark.parametrize("num_writes", [10, 100, 500])
def test_sram_magma(num_writes):

    [Mem, tester, MCore] = make_memory_core()
    mode = Mode.SRAM
    tile_en = 1
    depth = num_writes
    config_data = []
    config_data.append((MCore.get_reg_index("depth"), depth, 0))
    config_data.append((MCore.get_reg_index("tile_en"), tile_en, 0))
    config_data.append((MCore.get_reg_index("mode"), mode.value, 0))
    for addr, data, feat in config_data:
        tester.configure(addr, data, feat)
    memory_size = 1024
    tester.functional_model.config_sram(memory_size)

    def get_fresh_addr(reference):
        """
        Convenience function to get an address not already in reference
        """
        addr = random.randint(0, memory_size - 1)
        while addr in reference:
            addr = random.randint(0, memory_size - 1)
        return addr

    addrs = set()
    # Perform a sequence of random writes
    for i in range(num_writes):
        addr = get_fresh_addr(addrs)
        data = random.randint(0, (1 << 10))
        tester.write(data, addr)
        addrs.add(addr)

    # Read the values we wrote to make sure they are there
    for addr in addrs:
        tester.read(addr)

    for i in range(num_writes):
        addr = get_fresh_addr(addrs)
        tester.read_and_write(random.randint(0, (1 << 10)), addr)
        tester.read(addr)

    with tempfile.TemporaryDirectory() as tempdir:
        for genesis_verilog in glob.glob("genesis_verif/*.*"):
            shutil.copy(genesis_verilog, tempdir)
        tester.compile_and_run(directory=tempdir,
                               magma_output="coreir-verilog",
                               target="verilator",
                               flags=["-Wno-fatal"])

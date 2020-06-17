from gemstone.common.testers import BasicTester
from gemstone.common.run_verilog_sim import irun_available
from peak_core.peak_core import PeakCore
from peak.peak_wrapper import wrap_peak_class
from peak.family import PyFamily

import hwtypes
import shutil
import tempfile
import os
import pytest


from peak import Peak, family_closure, name_outputs, family
from functools import lru_cache
import magma as m
from hwtypes.adt import Tuple
from lassen.sim import PE_fc, Inst_fc

from lassen.asm import (add, Mode_t, lut_and, inst, ALU_t, Cond_t, 
                        umult0, fp_mul, fp_add,
                        fcnvexp2f, fcnvsint2f, fcnvuint2f)


from peak_gen.sim import pe_arch_closure
from peak_gen.isa import inst_arch_closure
from peak_gen.arch import read_arch
from peak_gen.asm import asm_arch_closure

@pytest.fixture(scope="module")
def dw_files():
    filenames = ["DW_fp_add.v", "DW_fp_mult.v"]
    dirname = "peak_core"
    result_filenames = []
    for name in filenames:
        filename = os.path.join(dirname, name)
        assert os.path.isfile(filename)
        result_filenames.append(filename)
    return result_filenames

def test_new_pe(dw_files):

    # PE_wrapped_fc = wrap_peak_class(PE_fc, Inst_fc)

    core = PeakCore(PE_fc)
    core.name = lambda: "PECore"
    circuit = core.circuit()

    # random test stuff
    tester = BasicTester(circuit, circuit.clk, circuit.reset)
    tester.reset()

    tester.poke(circuit.interface["stall"], 0)
    config_data = core.get_config_bitstream(add())

    for addr, data in config_data:
        print("{0:08X} {1:08X}".format(addr, data))
        tester.configure(addr, data)
        tester.config_read(addr)
        tester.eval()

    for i in range(10):
        tester.poke(circuit.interface["data0"], 0x42)
        tester.poke(circuit.interface["data1"], 0x42)
        tester.eval()
        tester.print("O=%d\n", circuit.interface["alu_res_0"])
        tester.expect(circuit.interface["alu_res_0"], 0x42 + 0x42)


    with tempfile.TemporaryDirectory() as tempdir:
        for filename in dw_files:
            shutil.copy(filename, tempdir)
        tester.compile_and_run(target="verilator",
                               magma_output="coreir-verilog",
                               magma_opts={"coreir_libs": {"float_DW"}},
                               directory=tempdir,
                               flags=["-Wno-fatal"])


def test_peak_generator():

    arch = read_arch(str("../../peak_generator/examples/misc_tests/test_add.json"))
    PE_fc = pe_arch_closure(arch)
    Inst_fc = inst_arch_closure(arch)

    asm_fc = asm_arch_closure(arch)
    gen_inst = asm_fc(family.PyFamily())

    PE_wrapped_fc = wrap_peak_class(PE_fc, Inst_fc)

    core = PeakCore(PE_wrapped_fc)
    core.name = lambda: "PECore"
    circuit = core.circuit()

    # random test stuff
    tester = BasicTester(circuit, circuit.clk, circuit.reset)
    tester.reset()

    tester.poke(circuit.interface["stall"], 0)
    config_data = core.get_config_bitstream(gen_inst())

    for addr, data in config_data:
        print("{0:08X} {1:08X}".format(addr, data))
        tester.configure(addr, data)
        tester.config_read(addr)
        tester.eval()

    for i in range(10):
        tester.poke(circuit.interface["inputs0"], 0x42)
        tester.poke(circuit.interface["inputs1"], 0x42)
        tester.eval()
        tester.print("O=%d\n", circuit.interface["PE_res_0"])
        tester.expect(circuit.interface["PE_res_0"], 0x42 + 0x42)


    with tempfile.TemporaryDirectory() as tempdir:
        # for filename in dw_files:
        #     shutil.copy(filename, tempdir)
        tester.compile_and_run(target="verilator",
                               magma_output="coreir-verilog",
                            #    magma_opts={"coreir_libs": {"float_DW"}},
                               directory=tempdir,
                               flags=["-Wno-fatal"])
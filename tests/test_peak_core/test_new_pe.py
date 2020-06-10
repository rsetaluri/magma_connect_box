from gemstone.common.testers import BasicTester
from gemstone.common.run_verilog_sim import irun_available
from peak_core.peak_core import PeakCore

from peak.family import PyFamily

import hwtypes
import shutil
import tempfile
import os
import pytest


from peak import Peak, family_closure, name_outputs
from functools import lru_cache
import magma as m
from hwtypes.adt import Tuple
from lassen.common import *
from lassen.mode import gen_register_mode
from lassen.lut import LUT_fc
from lassen.alu import ALU_fc
from lassen.cond import Cond_fc
from lassen.isa import Inst_fc
from lassen.asm import (add, Mode_t, lut_and, inst, ALU_t, Cond_t, 
                        umult0, fp_mul, fp_add,
                        fcnvexp2f, fcnvsint2f, fcnvuint2f)

@family_closure
def PE_fc(family):
    BitVector = family.BitVector

    Data = family.BitVector[DATAWIDTH]
    Bit = family.Bit

    ALU = ALU_fc(family)
    Cond = Cond_fc(family)
    LUT = LUT_fc(family)
    Inst = Inst_fc(family)


    DataInputList = Tuple[(Data for _ in range(2))]

    @family.assemble(locals(), globals())
    class PE(Peak):
        def __init__(self):

            #ALU
            self.alu: ALU = ALU()

            #Condition code
            self.cond: Cond = Cond()

            #Lut
            self.lut: LUT = LUT()

        @name_outputs(alu_res=Data, res_p=Bit)
        def __call__(self, inst: Inst, \
            inputs : DataInputList, \
            bit0: Bit = Bit(0), bit1: Bit = Bit(0), bit2: Bit = Bit(0), \
            clk_en: Global(Bit) = Bit(1)
        ) -> (Data, Bit):
            # Simulate one clock cycle

            # calculate alu results
            alu_res, alu_res_p, Z, N, C, V = self.alu(inst.alu, inst.signed, inputs[0], inputs[1], bit0)

            # calculate lut results
            lut_res = self.lut(inst.lut, bit0, bit1, bit2)

            # calculate 1-bit result
            res_p = self.cond(inst.cond, alu_res_p, lut_res, Z, N, C, V)

            # return 16-bit result, 1-bit result
            return alu_res, res_p

    return PE



def test_new_pe():
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
        tester.poke(circuit.interface["input0"], 0x42)
        tester.poke(circuit.interface["input1"], 0x42)
        tester.eval()
        tester.print("O=%d\n", circuit.interface["alu_res"])
        tester.expect(circuit.interface["alu_res"], 0x42 + 0x42)


    with tempfile.TemporaryDirectory() as tempdir:
        for filename in dw_files:
            shutil.copy(filename, tempdir)
        tester.compile_and_run(target="verilator",
                               magma_output="coreir-verilog",
                               magma_opts={"coreir_libs": {"float_DW"}},
                               directory=tempdir,
                               flags=["-Wno-fatal"])

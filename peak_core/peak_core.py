import math
import hwtypes
import magma
import peak
from peak.assembler import Assembler
from peak.family import PyFamily, MagmaFamily

import mantle
from gemstone.common.core import ConfigurableCore, PnRTag
from gemstone.common.configurable import ConfigurationType
from gemstone.generator.from_magma import FromMagma
from gemstone.generator.generator import Generator
from collections import OrderedDict
from .data_gate import data_gate


class HashableDict(dict):
    def __hash__(self):
        return hash(tuple(sorted(self.keys())))


def _convert_type(typ):
    if issubclass(typ, hwtypes.AbstractBit):
        return magma.Bits[1]
    return magma.Bits[typ.size]


class _PeakWrapperMeta(type):
    _cache = {}

    def __call__(cls, peak_generator):
        key = id(peak_generator)
        if key in _PeakWrapperMeta._cache:
            return _PeakWrapperMeta._cache[key]
        self = super().__call__(peak_generator)
        _PeakWrapperMeta._cache[key] = self
        return self


class _PeakWrapper(metaclass=_PeakWrapperMeta):
    def __init__(self, peak_generator):
        pe = peak_generator.Py
        assert issubclass(pe, peak.Peak)
        self._model = pe()
        #Lassen's name for the ISA is 'inst', so this is hardcoded
        self.__instr_name = 'inst'
        self.__instr_type = pe.input_t.field_dict['inst']

        inputs = OrderedDict(pe.input_t.field_dict)


        self.__inputs = inputs

        del self.__inputs['inst']

        self.__outputs = OrderedDict(pe.output_t.field_dict)
        circuit = peak_generator(MagmaFamily())
        self.__asm = Assembler(self.__instr_type)
        instr_magma_type = type(circuit.interface.ports[self.__instr_name])
        self.__circuit = peak.wrap_with_disassembler(
            circuit, self.__asm.disassemble, self.__asm.width,
            HashableDict(self.__asm.layout),
            instr_magma_type)
        data_gate(self.__circuit)

    @property
    def model(self):
        return self._model

    def rtl(self):
        return self.__circuit

    def inputs(self):
        return self.__inputs

    def outputs(self):
        return self.__outputs

    def instruction_name(self):
        return self.__instr_name

    def instruction_type(self):
        return self.__instr_type

    def instruction_width(self):
        return self.__asm.width

    def assemble(self, instr):
        return self.__asm.assemble(instr)


class PeakCore(ConfigurableCore):
    def __init__(self, peak_generator):
        super().__init__(8, 32)
        self.ignored_ports = {"clk_en", "reset", "config_addr", "config_data",
                              "config_en", "read_config_data"}


        self.wrapper = _PeakWrapper(peak_generator)

        # Generate core RTL (as magma).
        self.peak_circuit = FromMagma(self.wrapper.rtl())

        # Add input/output ports and wire them.
        inputs = self.wrapper.inputs()
        outputs = self.wrapper.outputs()

        for ports, dir_ in ((inputs, magma.In), (outputs, magma.Out),):
  
            for i, (name, typ) in enumerate(ports.items()):
                
                if name in self.ignored_ports:
                    continue
                magma_type = _convert_type(typ)
                self.add_port(name, dir_(magma_type))
                my_port = self.ports[name]
                if magma_type is magma.Bits[1]:
                    my_port = my_port[0]
                magma_name = name if dir_ is magma.In else f"O{i}"

                self.wire(my_port, self.peak_circuit.ports[magma_name])


        self.add_ports(
            config=magma.In(ConfigurationType(8, 32)),
            stall=magma.In(magma.Bits[1])
        )


        # Set up configuration for PE instruction. Currently, we perform a naive
        # partitioning of the large instruction into 32-bit config registers.
        config_width = self.wrapper.instruction_width()
        num_config = math.ceil(config_width / 32)
        instr_name = self.wrapper.instruction_name()
        self.reg_width = {}
        for i in range(num_config):
            name = f"{instr_name}_{i}"
            self.add_config(name, 32)
            lb = i * 32
            ub = min(i * 32 + 32, config_width)
            len_ = ub - lb
            self.reg_width[name] = len_
            self.wire(self.registers[name].ports.O[:len_],
                      self.peak_circuit.ports[instr_name][lb:ub])

        # connecting the wires
        # TODO: connect this wire once lassen has async reset
        self.wire(self.ports.reset, self.peak_circuit.ports.ASYNCRESET)

        # PE core uses clk_en (essentially active low stall)
        self.stallInverter = FromMagma(mantle.DefineInvert(1))
        self.wire(self.stallInverter.ports.I, self.ports.stall)
        self.wire(self.stallInverter.ports.O[0], self.peak_circuit.ports.clk_en)

        self._setup_config()

    def get_config_bitstream(self, instr):
        # breakpoint()
        # assert isinstance(instr, self.wrapper.instruction_type())
        config = self.wrapper.assemble(instr)
        config_width = self.wrapper.instruction_width()
        num_config = math.ceil(config_width / 32)
        instr_name = self.wrapper.instruction_name()
        result = []
        for i in range(num_config):
            name = f"{instr_name}_{i}"
            reg_idx = self.registers[name].addr
            data = int(config[i * 32:i * 32 + 32])
            result.append((reg_idx, data))
        return result

    def instruction_type(self):
        return self.wrapper.instruction_type()

    def inputs(self):
        return [self.ports[name] for name in self.wrapper.inputs()
                if name not in self.ignored_ports]

    def outputs(self):
        return [self.ports[name] for name in self.wrapper.outputs()
                if name not in self.ignored_ports]

    def pnr_info(self):
        # PE has highest priority
        return PnRTag("p", self.DEFAULT_PRIORITY, self.DEFAULT_PRIORITY)

    def name(self):
        return "PE"

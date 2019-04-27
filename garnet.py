import argparse
import magma
import canal
import coreir
from canal.cyclone import SwitchBoxSide, SwitchBoxIO
from canal.interconnect import Interconnect
from canal.global_signal import apply_global_parallel_meso_wiring
from canal.util import create_uniform_interconnect, SwitchBoxType, IOSide
from power_domain.pd_pass import add_power_domain
from gemstone.common.jtag_type import JTAGType
from gemstone.generator.generator import Generator
from global_controller.global_controller_magma import GlobalController
from global_buffer.global_buffer_magma import GlobalBuffer
from global_buffer.mmio_type import MMIOType
from memory_core.memory_core_magma import MemCore
from lassen.sim import gen_pe
from peak_core.peak_core import PeakCore
from io_core.io_core_magma import IOCore
import metamapper
import subprocess
import os
import math
import archipelago
# TODO: remove this import
from gemstone.generator.const import Const


class Garnet(Generator):
    def __init__(self, width, height, add_pd):
        super().__init__()

        # configuration parameters
        config_addr_width = 32
        config_data_width = 32
        tile_id_width = 16
        config_addr_reg_width = 8
        num_tracks = 5

        # global buffer parameters
        num_banks = 32
        bank_addr = 17
        bank_data = 64
        glb_addr = math.ceil(math.log2(num_banks)) + bank_addr

        # SoC ctrl parameter
        soc_addr_width = 12

        # parallel configuration parameter
        num_cfg = math.ceil(width/4)

        # number of input/output channels parameter
        # this must be at least 2
        num_io = max(math.ceil(width/4), 2)

        self.global_controller = GlobalController(config_addr_width,
                                                  config_data_width,
                                                  soc_addr_width)
        self.global_buffer = GlobalBuffer(num_banks=num_banks, num_io=num_io,
                                          num_cfg=num_cfg, bank_addr=bank_addr,
                                          top_cfg_addr=soc_addr_width)

        cores = {}
        margin = 1
        # Use the new height due to the margin.
        width += 2 * margin
        height += 2 * margin

        cores = {}
        for x in range(width):
            for y in range(height):
                # Empty corner.
                if x in range(margin) and y in range(margin):
                    core = None
                elif x in range(margin) and y in range(height - margin,
                                                       height):
                    core = None
                elif x in range(width - margin,
                                width) and y in range(margin):
                    core = None
                elif x in range(width - margin,
                                width) and y in range(height - margin,
                                                      height):
                    core = None
                elif x in range(margin) \
                        or x in range(width - margin, width) \
                        or y in range(margin) \
                        or y in range(height - margin, height):
                    if x == margin:
                        core = IOCore()
                    else:
                        core = None
                else:
                    core = MemCore(16, 1024) if ((x - margin) % 2 == 1) else \
                        PeakCore(gen_pe)
                cores[(x, y)] = core

        def create_core(xx: int, yy: int):
            return cores[(xx, yy)]

        # Specify input and output port connections.
        inputs = set()
        outputs = set()
        for core in cores.values():
            # Skip IO cores.
            if core is None or isinstance(core, IOCore):
                continue
            inputs |= {i.qualified_name() for i in core.inputs()}
            outputs |= {o.qualified_name() for o in core.outputs()}

        # This is slightly different from the original CGRA. Here we connect
        # input to every SB_IN and output to every SB_OUT.
        port_conns = {}
        in_conn = [(side, SwitchBoxIO.SB_IN) for side in SwitchBoxSide]
        out_conn = [(side, SwitchBoxIO.SB_OUT) for side in SwitchBoxSide]
        port_conns.update({input_: in_conn for input_ in inputs})
        port_conns.update({output: out_conn for output in outputs})
        sides = (IOSide.North)

        ic_graphs = {}
        io_in = {"f2io_16": [0], "f2io_1": [1]}
        io_out = {"io2f_16": [0], "io2f_1": [1]}
        io_conn = {"in": io_in, "out": io_out}
        pipeline_regs = []
        for track in range(num_tracks):
            for side in SwitchBoxSide:
                pipeline_regs.append((track, side))
        for bit_width in (1, 16):
            ic_graph = create_uniform_interconnect(width, height, bit_width,
                                                   create_core, port_conns,
                                                   {1: num_tracks},
                                                   SwitchBoxType.Disjoint,
                                                   pipeline_regs,
                                                   io_sides=sides,
                                                   io_conn=io_conn)
            ic_graphs[bit_width] = ic_graph

        lift_ports = margin == 0
        self.interconnect = Interconnect(ic_graphs, config_addr_reg_width,
                                         config_data_width, tile_id_width,
                                         lift_ports=lift_ports)
        if add_pd:
            print("add power domain")
            add_power_domain(self.interconnect)
        self.interconnect.finalize()

        # Apply global wiring.
        apply_global_parallel_meso_wiring(self.interconnect, sides, num_cfg)

        # Lift interconnect ports.
        for name in self.interconnect.interface():
            self.add_port(name, self.interconnect.ports[name].type())
            self.wire(self.ports[name], self.interconnect.ports[name])

        self.add_ports(
            jtag=JTAGType,
            clk_in=magma.In(magma.Clock),
            reset_in=magma.In(magma.AsyncReset),
            soc_data=MMIOType(glb_addr, bank_data),
            soc_ctrl=MMIOType(soc_addr_width, config_data_width),
            soc_interrupt=magma.Out(magma.Bit),
        )

        # top <-> global controller ports connection
        self.wire(self.ports.jtag, self.global_controller.ports.jtag)
        self.wire(self.ports.clk_in, self.global_controller.ports.clk_in)
        self.wire(self.ports.reset_in, self.global_controller.ports.reset_in)
        self.wire(self.ports.soc_ctrl, self.global_controller.ports.soc_ctrl)
        self.wire(self.ports.soc_interrupt,
                  self.global_controller.ports.soc_interrupt)

        # global controller <-> interconnect ports connection
        self.wire(self.global_controller.ports.clk_out,
                  self.interconnect.ports.clk)
        self.wire(self.global_controller.ports.reset_out,
                  self.interconnect.ports.reset)
        self.wire(self.global_controller.ports.stall,
                  self.interconnect.ports.stall)

        self.wire(self.interconnect.ports.read_config_data,
                  self.global_controller.ports.read_data_in)
        # TODO: done_pulse signal should go to global controller
        #       For now, just connect it to 0
        self.wire(self.global_controller.ports.cgra_done_pulse,
                  Const(magma.bit(0)))
        # TODO: start_pulse signal should go to interconnect

        # top <-> global buffer ports connection
        self.wire(self.ports.soc_data, self.global_buffer.ports.soc_data)

        # global controller <-> global buffer ports connection
        self.wire(self.global_controller.ports.clk_out,
                  self.global_buffer.ports.clk)
        self.wire(self.global_controller.ports.reset_out,
                  self.global_buffer.ports.reset)
        self.wire(self.global_controller.ports.glb_stall,
                  self.global_buffer.ports.glc_to_io_stall)
        self.wire(self.global_controller.ports.config,
                  self.global_buffer.ports.cgra_config)
        self.wire(self.global_controller.ports.top_config,
                  self.global_buffer.ports.top_config)
        self.wire(self.global_controller.ports.top_read_data_in,
                  self.global_buffer.ports.top_config_rd_data)
        self.wire(self.global_controller.ports.glb_config,
                  self.global_buffer.ports.glb_config)
        self.wire(self.global_controller.ports.glb_read_data_in,
                  self.global_buffer.ports.glb_config_rd_data)
        self.wire(self.global_controller.ports.cgra_start_pulse,
                  self.global_buffer.ports.cgra_start_pulse)
        self.wire(self.global_controller.ports.config_start_pulse,
                  self.global_buffer.ports.config_start_pulse)
        self.wire(self.global_controller.ports.config_done_pulse,
                  self.global_buffer.ports.config_done_pulse)

        for i in range(num_cfg):
            self.wire(self.global_buffer.ports.glb_to_cgra_config[i],
                      self.interconnect.ports.config[i])

        # TODO: io streams should be connected to interconnect
        #       For now, just ground every ports
        for i in range(self.num_io):
            self.wire(self.global_buffer.ports.cgra_to_io_wr_data[i],
                      Const(magma.bits(0, 16)))
            self.wire(self.global_buffer.ports.cgra_to_io_addr_high[i],
                      Const(magma.bits(0, 16)))
            self.wire(self.global_buffer.ports.cgra_to_io_addr_low[i],
                      Const(magma.bits(0, 16)))
            self.wire(self.global_buffer.ports.cgra_to_io_rd_en[i],
                      Const(magma.bit(0)))
            self.wire(self.global_buffer.ports.cgra_to_io_wr_en[i],
                      Const(magma.bit(0)))

        self.mapper_initalized = False

    def initialize_mapper(self):
        if self.mapper_initalized:
            raise RuntimeError("Can not initialize mapper twice")
        # Set up compiler and mapper.
        self.coreir_context = coreir.Context()
        self.mapper = metamapper.PeakMapper(self.coreir_context, "lassen")
        self.mapper.add_io_and_rewrite("io1", 1, "io2f_1bit", "f2io_1bit")
        self.mapper.add_io_and_rewrite("io16", 16, "io2f_16bit", "f2io_16bit")
        self.mapper.add_peak_primitive("PE", gen_pe)

        # Hack to speed up rewrite rules discovery.
        def bypass_mode(inst):
            return (
                inst.rega == type(inst.rega).BYPASS and
                inst.regb == type(inst.regb).BYPASS and
                inst.regd == type(inst.regd).BYPASS and
                inst.rege == type(inst.rege).BYPASS and
                inst.regf == type(inst.regf).BYPASS
            )
        self.mapper.add_discover_constraint(bypass_mode)

        self.mapper.discover_peak_rewrite_rules(width=16)

        self.mapper_initalized = True

    def map(self, halide_src):
        assert self.mapper_initalized
        app = self.coreir_context.load_from_file(halide_src)
        instrs = self.mapper.map_app(app)
        return app, instrs

    def run_pnr(self, info_file, mapped_file):
        cgra_path = os.getenv("CGRA_PNR", "")
        assert cgra_path != "", "Cannot find CGRA PnR"
        entry_point = os.path.join(cgra_path, "scripts", "pnr_flow.sh")
        subprocess.check_call([entry_point, info_file, mapped_file])

    def get_placement_bitstream(self, placement, id_to_name, instrs):
        result = []
        for node, (x, y) in placement.items():
            instance = id_to_name[node]
            if instance not in instrs:
                continue
            instr = instrs[instance]
            result += self.interconnect.configure_placement(x, y, instr)
        return result

    def convert_mapped_to_netlist(self, mapped):
        raise NotImplemented()

    def compile(self, halide_src):
        if not self.mapper_initalized:
            self.initialize_mapper()
        mapped, instrs = self.map(halide_src)
        # id to name converts the id to instance name
        netlist, bus, id_to_name = self.convert_mapped_to_netlist(mapped)
        placement, routing = archipelago.pnr(self.interconnect, (netlist, bus))
        bitstream = []
        bitstream += self.interconnect.get_route_bitstream(routing)
        bitstream += self.get_placement_bitstream(placement, id_to_name,
                                                  instrs)
        return bitstream

    def name(self):
        return "Garnet"


def main():
    parser = argparse.ArgumentParser(description='Garnet CGRA')
    parser.add_argument('--width', type=int, default=2)
    parser.add_argument('--height', type=int, default=2)
    parser.add_argument("--input-netlist", type=str, default="", dest="input")
    parser.add_argument("--output-bitstream", type=str, default="",
                        dest="output")
    parser.add_argument("-v", "--verilog", action="store_true")
    parser.add_argument("--no-pd", "--no-power-domain", action="store_true")
    args = parser.parse_args()

    garnet = Garnet(width=args.width, height=args.height, add_pd=not args.no_pd)
    if args.verilog:
        garnet_circ = garnet.circuit()
        magma.compile("garnet", garnet_circ, output="coreir-verilog")
    if len(args.input) > 0 and len(args.output) > 0:
        # do PnR and produce bitstream
        bitstream = garnet.compile(args.input)
        with open(args.output, "w+") as f:
            bs = ["{0:08X} {1:08X}".format(entry[0], entry[1]) for entry
                  in bitstream]
            f.write("\n".join(bs))


if __name__ == "__main__":
    main()

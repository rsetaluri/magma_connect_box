import metamapper.coreir_util as cutil
from metamapper.common_passes import VerifyNodes, print_dag
from metamapper import CoreIRContext
from metamapper.irs.coreir import gen_CoreIRNodes
from metamapper.lake_mem import gen_MEM_fc
from lassen.sim import PE_fc as lassen_fc
import metamapper.peak_util as putil
from mapper.netlist_util import create_netlist_info, print_netlist_info

from canal.util import IOSide
from cgra import create_cgra, compress_config_data
from archipelago import pnr

import pytest


@pytest.fixture()
def io_sides():
    return IOSide.North | IOSide.East | IOSide.South | IOSide.West


@pytest.mark.parametrize("app", [
    "add3_const_mapped",
    #"pointwise_to_metamapper",
    #"gaussian_to_metamapper",
    #"harris_to_metamapper",
])
def test_post_mapped(app, io_sides):
    base = "src/metamapper"
    lassen_header = f"{base}/libs/lassen_header.json"
    mem_header = f"{base}/libs/mem_header.json"

    app_file = f"{base}/examples/post_mapping/{app}.json"
    c = CoreIRContext(reset=True)
    cmod = cutil.load_from_json(app_file)
    #cmod.print_()
    c = CoreIRContext()
    c.run_passes(["flatten"])
    #cmod.print_()

    MEM_fc = gen_MEM_fc()
    # Contains an empty nodes
    nodes = gen_CoreIRNodes(16)
    putil.load_and_link_peak(
        nodes,
        lassen_header,
        {"global.PE": lassen_fc},
    )
    putil.load_and_link_peak(
        nodes,
        mem_header,
        {"global.MEM": MEM_fc},
    )
    dag = cutil.coreir_to_dag(nodes, cmod)
    #print_dag(dag)
    print("-"*80)
    tile_info = {"global.PE": lassen_fc, "global.MEM": MEM_fc}
    netlist_info = create_netlist_info(dag, tile_info)
    print_netlist_info(netlist_info)

    chip_size = 4
    interconnect = create_cgra(chip_size, chip_size, io_sides,
                               num_tracks=3,
                               add_pd=False,
                               mem_ratio=(1, 2))

    placement, routing = pnr(interconnect, (netlist_info['netlist'], netlist_info['buses']))
    config_data = interconnect.get_route_bitstream(routing)

    print("CD", config_data)
    assert 0

    arch = read_arch(str("dse_pes/pointwise_pe.json"))
    asm_fc = asm_arch_closure(arch)
    gen_inst = asm_fc(family.PyFamily())

    x, y = placement["p0"]
    tile = interconnect.tile_circuits[(x, y)]
    add_bs = tile.core.get_config_bitstream(gen_inst())
    for addr, data in add_bs:
        config_data.append((interconnect.get_config_addr(addr, 0, x, y), data))
    config_data = compress_config_data(config_data)

    circuit = interconnect.circuit()
#examples_coreir = [
#    "add2",
#    "pipe",
#    "add4_pipe",
#    "add1_const",
#    "add3",
#    "add4",
#    "add3_const"
#]



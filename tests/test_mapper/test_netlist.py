import metamapper.coreir_util as cutil
from metamapper.common_passes import VerifyNodes, print_dag
from metamapper import CoreIRContext
from metamapper.irs.coreir import gen_CoreIRNodes
import pytest

from mapper.netlist_util import create_netlist_info, print_netlist_info



from metamapper.lake_mem import gen_MEM_fc
from lassen.sim import PE_fc as lassen_fc
import metamapper.peak_util as putil

@pytest.mark.parametrize("app", [
    "add3_const_mapped",
    #"pointwise_to_metamapper",
    #"gaussian_to_metamapper",
    #"harris_to_metamapper",
])
def test_post_mapped(app):
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

    netlist_info = create_netlist_info(dag)
    print_netlist_info(netlist_info)


examples_coreir = [
    "add2",
    #"pipe",
    #"add4_pipe",
    #"add1_const",
    #"add3",
    #"add4",
    #"add3_const"
]



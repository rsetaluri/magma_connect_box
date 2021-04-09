from lassen.sim import PE_fc
from peak_core.peak_core import PeakCore
import magma as m

pe_core = PeakCore(PE_fc)

ret = m.compile("PE", pe_core.circuit(), output="coreir-verilog",
          coreir_libs={"float_CW"},
          passes = ["rungenerators", "inline_single_instances", "clock_gate"],
          disable_ndarray=True,
          inline=False,
          generate_symbols=True)

with open("PE_symbol_table.json", "w") as f:
    f.write(ret["master_symbol_table"].as_json())

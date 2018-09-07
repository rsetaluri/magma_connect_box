import magma
import generator.generator as generator
from global_controller.global_controller_magma import GlobalController
from interconnect.interconnect_magma import Interconnect
from column.column_magma import Column
from tile.tile_magma import Tile
from pe_core.pe_core_magma import PECore
from memory_core.memory_core_magma import MemCore
from common.side_type import SideType
from common.jtag_type import JTAGType


class CGRA(generator.Generator):
    def __init__(self, width, height):
        super().__init__()

        self.global_controller = GlobalController(32, 32)
        columns = []
        for i in range(width):
            tiles = []
            for j in range(height):
                core = MemCore() if (i % 2) else PECore()
                tiles.append(Tile(core))
            columns.append(Column(tiles))
        self.interconnect = Interconnect(columns)

        side_type = self.interconnect.side_type
        self.add_ports(
            north=magma.Array(width, side_type),
            south=magma.Array(width, side_type),
            west=magma.Array(height, side_type),
            east=magma.Array(height, side_type),
            jtag=JTAGType,
            clk_in=magma.In(magma.Clock),
            reset_in=magma.In(magma.Reset),
        )

        self.wire(self.north, self.interconnect.north)
        self.wire(self.south, self.interconnect.south)
        self.wire(self.west, self.interconnect.west)
        self.wire(self.east, self.interconnect.east)

        self.wire(self.jtag, self.global_controller.jtag)
        self.wire(self.clk_in, self.global_controller.clk_in)
        self.wire(self.reset_in, self.global_controller.reset_in)

        self.wire(self.global_controller.config, self.interconnect.config)
        self.wire(self.global_controller.clk_out, self.interconnect.clk)
        self.wire(self.global_controller.reset_out, self.interconnect.rst)

    def name(self):
        return "CGRA"


def main():
    cgra = CGRA(4, 4)
    cgra_circ = cgra.circuit()
    magma.compile("cgra", cgra_circ, output="coreir-verilog", split="build/")


if __name__ == "__main__":
    main()

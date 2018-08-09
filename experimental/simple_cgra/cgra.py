import generator
import magma
from global_controller import GlobalController
from interconnect import Interconnect
from column import Column
from tile import Tile
from pe_core import PECore
from side_type import SideType
from jtag_type import JTAGType


class CGRA(generator.Generator):
    def __init__(self, width, height):
        super().__init__()

        self.global_controller = GlobalController(32, 32)
        columns = []
        for i in range(width):
            tiles = []
            for j in range(height):
                tiles.append(Tile(PECore()))
            columns.append(Column(tiles))
        self.interconnect = Interconnect(columns)

        self.add_ports(
            north=magma.Array(width, SideType(5, (1, 16))),
            south=magma.Array(width, SideType(5, (1, 16))),
            west=magma.Array(height, SideType(5, (1, 16))),
            east=magma.Array(height, SideType(5, (1, 16))),
            jtag_in=magma.In(JTAGType),
        )

        self.wire(self.north, self.interconnect.north)
        self.wire(self.south, self.interconnect.south)
        self.wire(self.west, self.interconnect.west)
        self.wire(self.east, self.interconnect.east)
        self.wire(self.jtag_in, self.global_controller.jtag_in)

    def name(self):
        return "CGRA"


def main():
    cgra = CGRA(4, 4)
    circ = cgra.circuit()
    print (circ)


if __name__ == "__main__":
    main()

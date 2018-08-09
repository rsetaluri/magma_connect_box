import generator
import magma
from side_type import SideType


class Column(generator.Generator):
    def __init__(self, tiles):
        super().__init__()

        self.tiles = tiles
        self.height = len(tiles)

        self.add_ports(
            north=SideType(5, (1, 16)),
            south=SideType(5, (1, 16)),
            west=magma.Array(self.height, SideType(5, (1, 16))),
            east=magma.Array(self.height, SideType(5, (1, 16))),
        )

        self.wire(self.north, self.tiles[0].north)
        self.wire(self.south, self.tiles[-1].south)
        for i, tile in enumerate(self.tiles):
            self.wire(self.west[i], tile.west)
            self.wire(self.east[i], tile.east)
        for i in range(1, self.height):
            t0 = self.tiles[i - 1]
            t1 = self.tiles[i]
            self.wire(t0.south, t1.north)

    def name(self):
        return "Column"

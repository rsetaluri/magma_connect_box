def create_stub(width):
    result = """
module Interconnect (
input  clk,
input [31:0] config_config_addr,
input [31:0] config_config_data,
input [0:0] config_read,
input [0:0] config_write,
output [31:0] read_config_data,
input  reset,
input [3:0] stall,

"""
    # loop through the interfaces
    ports = []
    for i in range(width):
        for bit_width in [1, 16]:
            ports.append(f"input [{bit_width-1}:0] glb2io_{bit_width}_X{i:02X}_Y00")
            ports.append(f"output [{bit_width - 1}:0] io2glb_{bit_width}_X{i:02X}_Y00")
    result += ",\n".join(ports)
    result += "\n);\n"

    # read the actual logic in
    with open("cgra_stub_logic.sv") as f:
        result += f.read()

    result += "\nendmodule\n"

    return result


if __name__ == "__main__":
    import sys
    assert len(sys.argv) == 2
    w = int(sys.argv[1])
    s = create_stub(w)
    with open("cgra_stub.sv", "w+") as f_:
        f_.write(s)
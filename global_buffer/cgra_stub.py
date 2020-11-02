import argparse


def create_stub(width, args):
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

    # instantiate the stub logic
    for idx, (input_filename, x_start, x_out) in enumerate(args):
        x_start = int(x_start)
        x_out = int(x_out)
        stub = f"""output_port #(.OUTPUT_FILE_NAME(\"{input_filename}\")) port_{idx}
        (.clk(clock), .reset(reset), .start(glb2io_1_X{x_start:02X}_Y00),
        .valid_out(io2glb_1_X{x_out:02X}_Y00), .data_out(io2glb_16_X{x_out:02X}_Y00));\n\n"""
        result += stub

    result += "\nendmodule\n"

    return result


def main():
    parser = argparse.ArgumentParser("Stub generator")
    parser.add_argument("-w", "--width", type=int, action="store", required=True)
    parser.add_argument("-a", "--apps", action="append", nargs=3,
                        required=True)
    args = parser.parse_args()
    for _, x_start, x_out in args.apps:
        assert int(x_start) < args.width
        assert int(x_out) < args.width

    s = create_stub(args.width, args.apps)
    with open("cgra_stub.sv", "w+") as f_:
        f_.write(s)


if __name__ == "__main__":
    main()

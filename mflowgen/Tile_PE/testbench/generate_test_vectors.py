from random import random
import math
import numpy as np
import binascii
import struct
import os
import csv
import re
from defines import inputs, outputs

def convert_raw(signals, input_file, output_file):
    dim_pattern = re.compile("\w*\[(\d+):0\]")
    raw = open(input_file, "r")
    f = open(output_file, "w")

    data = list(csv.reader(raw, delimiter=','))
    headers = data[0]

    widths = {}
    col = {}
    for i,h in enumerate(headers):
        name = h.split('.')[-1]
        try:
            width = int(dim_pattern.match(name).groups()[0]) + 1
            name = name.replace(f'[{width-1}:0]', '')
            widths[name] = width
        except:
            widths[name] = 1
        col[name] = i

    for c in range(1,len(data)):
        to_write = []
        for s in signals:
            value = data[c][col[s]]

            # append leading zeros to pad up to 16 bits (4 hex spaces)
            while len(value) % 4 != 0:
                value = "0"+value

            for i in range(int((len(value) - 1) / 4) + 1):
                partial_value = value[i*4:min((i+1)*4, len(value)+1)]
                to_write.append(partial_value)
        to_write.reverse()
        f.write('_'.join(to_write)+'\n')
             
    f.close()
    raw.close()
    
    num_test_vectors = len(data) - 1
    return num_test_vectors, widths

def create_testbench(inputs, outputs, input_widths, output_widths, num_test_vectors):
    pwr_aware = os.environ.get("PWR_AWARE") == "True"

    tb = open("testbench.sv", "w")

    # write defines
    tb.write(f'`timescale 1ns/1ps\n')
    tb.write(f'`define NUM_TEST_VECTORS {num_test_vectors}\n')
    tb.write(f'`define ASSIGNMENT_DELAY 0.2 \n')
    tb.write(f'\n')

    input_base = 0
    for i in inputs:
        tb.write(f'`define SLICE_{i.upper()} {input_widths[i]-1+input_base}:{input_base}\n')
        input_base += input_widths[i]
        if input_widths[i] % 16 != 0:
            input_base += (16 - input_widths[i] % 16)
    tb.write('\n')
    output_base = 0
    for o in outputs:
        tb.write(f'`define SLICE_{o.upper()} {output_widths[o]-1+output_base}:{output_base}\n')
        output_base += output_widths[o]
        if output_widths[o] % 16 != 0:
            output_base += (16 - output_widths[o] % 16)

    tb.write(f'''
module TilePETb;

    localparam ADDR_WIDTH = $clog2(`NUM_TEST_VECTORS);
   
    reg [ADDR_WIDTH - 1 : 0] test_vector_addr;
 
    reg [{input_base}-1: 0] test_vectors [`NUM_TEST_VECTORS - 1 : 0];
    reg [{input_base}-1: 0] test_vector;

    reg [{output_base}-1: 0] test_outputs [`NUM_TEST_VECTORS - 1 : 0];
    reg [{output_base}-1: 0] test_output;

''')

    for i in inputs:
        if 'reset' not in i:
            tb.write(f'    wire [{input_widths[i]-1}:0] {i} = test_vectors[test_vector_addr][`SLICE_{i.upper()}];\n')
        else:
            tb.write(f'    wire {i} = test_vectors[test_vector_addr][`SLICE_{i.upper()}];\n')
    for o in outputs:
        tb.write(f'    wire [{output_widths[o]-1}:0] {o};\n')

    tb.write('''
    reg  clk;
    wire clk_out;
    reg  clk_pass_through;
    wire clk_pass_through_out_bot;
    wire clk_pass_through_out_right;
''')
    if pwr_aware:
        tb.write('''
    supply1 VDD;
    supply0 VSS;
''')


    tb.write('''
    Tile_PE Tile_PE_inst (
''')

    for i in inputs+outputs:
        tb.write(f'        .{i}({i}),\n')
    if pwr_aware:
        tb.write(f'''        .VDD(VDD),
        .VSS(VSS),
''')
    tb.write(f'''        .clk(clk),
        .clk_out(clk_out),
        .clk_pass_through(clk_pass_through),
        .clk_pass_through_out_bot(clk_pass_through_out_bot),
        .clk_pass_through_out_right(clk_pass_through_out_right)
    );

    always #(`CLK_PERIOD/2) clk =~clk;
    
    initial begin
      $readmemh("inputs/test_vectors.txt", test_vectors);
      $readmemh("inputs/test_outputs.txt", test_outputs);
      clk <= 0;
      test_vector_addr <= 0;
    end
  
    always @ (posedge clk) begin
        test_vector_addr <= # `ASSIGNMENT_DELAY (test_vector_addr + 1); // Don't change the inputs right after the clock edge because that will cause problems in gate level simulation
        test_vector <= test_vectors[test_vector_addr];
        test_output <= test_outputs[test_vector_addr];

        if (test_vector_addr >= {num_test_vectors}) begin
            $finish(2);
        end
''')
    for o in outputs:
        tb.write(f'''
        if ({o} != test_outputs[test_vector_addr][`SLICE_{o.upper()}] || $isunknown({o})) begin
            $display("{o}: got %x, expected %x", {o}, test_outputs[test_vector_addr][`SLICE_{o.upper()}]);
        end
''')

    tb.write('''
    end
  
    initial begin
        $sdf_annotate("inputs/design.sdf", TilePETb.Tile_PE_inst);
    end

endmodule''')

    tb.close()

def main():
    num_test_vectors, input_widths = convert_raw(inputs, "raw_input.csv", "test_vectors.txt")
    _, output_widths = convert_raw(outputs, "raw_output.csv", "test_outputs.txt")
    create_testbench(inputs, outputs, input_widths, output_widths, num_test_vectors)

if __name__ == '__main__':
    main()

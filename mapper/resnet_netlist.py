import json
import os

def create_resnet_netlist():

    netlist_info = {}
    netlist_info["netlist"] = {}
    netlist_info["bus"] = {}
    netlist_info["id_to_name"] = {}
    netlist_info["instance_to_instr"] = {}


    # with open("coreir_examples/post_mapped/resnet_lauer.json", "r") as read_file:
    #     data = json.load(read_file)

    # instances = data["resnet_layer_gen"]["instances"]
    # connections = data["resnet_layer_gen"]["connections"]

    # for instance in instances:
    #     if instance

    return netlist_info

# netlist
# {'e1': [('I3', 'io2f_16'), ('p1', 'data0')], 'e2': [('p1', 'alu_res'), ('I2', 'f2io_16')], 'e3': [('i5', 'io2f_1'), ('i4', 'f2io_1')]}

# bus
# {'e1': 16, 'e2': 16, 'e3': 1}

# id_to_name
# {'c0': 'compute_module_compute_kernel_0$const__U7_0', 'p1': 'compute_module_compute_kernel_0$mul_3$binop', 'I2': 'io16_out_0_0', 'I3': 'io16in_in_arg_0_0_0', 'i4': 'io1_valid', 'i5': 'io1in_in_en', 'i6': 'io1in_reset'}

# instance_to_instr
# {'compute_module_compute_kernel_0$mul_3$binop': Inst(alu=ALU_t.Mult0, signed=Signed_t.unsigned, lut=0, cond=Cond_t.Z, rega=Mode_t.BYPASS, data0=0, regb=Mode_t.CONST, data1=2, regd=Mode_t.BYPASS, bit0=Bit(False), rege=Mode_t.BYPASS, bit1=Bit(False), regf=Mode_t.BYPASS, bit2=Bit(False))}
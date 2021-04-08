from collections import defaultdict
from hwtypes.adt import Tuple, Product
from metamapper.node import Dag, Input, Output, Combine, Select, DagNode, IODag, Constant
from DagVisitor import Visitor
from hwtypes import Bit, BitVector

def sample_pnr_input():
    id_to_name = dict(
        I0="io_in",
        I1="io_out",
        p0="PE0",
    )
    inst_to_instr = dict(
        I0=1,
        I1=2,
        p0=17
    )
    netlist = dict(
        e0=[("I0", "io2f_16"), ("p0", "data0"), ("p0", "data1")],
        e1=[("p0", "alu_res"), ("I1", "f2io_16")]
    )
    buses = dict(
        e0=16,
        e1=16,
    )

    return id_to_name, inst_to_instr, netlist, buses


class CreateBuses(Visitor):
    def __init__(self, inst_info):
        self.inst_info = inst_info

    def doit(self, dag):
        self.i = 0
        self.bid_to_width = {}
        self.node_to_bid = {}
        self.netlist = defaultdict(lambda: [])
        self.run(dag)
        #Filter bid_to_width to contain only whats in self.netlist
        buses = {bid:w for bid,w in self.bid_to_width.items() if bid in self.netlist}
        return buses, self.netlist

    def create_buses(self, adt):
        if adt == Bit:
            bid = f"e{self.i}"
            self.bid_to_width[bid] = 1
            self.i += 1
            return bid
        elif adt == BitVector[16]:
            bid = f"e{self.i}"
            self.bid_to_width[bid] = 16
            self.i += 1
            return bid
        elif issubclass(adt, BitVector):
            return None
        elif issubclass(adt, Product):
            bids = {}
            for k, t in adt.field_dict.items():
                bid = self.create_buses(t)
                if bid is None:
                    continue
                assert isinstance(bid, str)
                bids[k] = bid
            return bids
        else:
            raise NotImplementedError(f"{adt}")

    def visit_Input(self, node):
        bid = self.create_buses(node.type)
        self.node_to_bid[node] = bid

    def visit_Constant(self, node):
        self.node_to_bid[node] = None

    def visit_Select(self, node):
        Visitor.generic_visit(self, node)
        child = list(node.children())[0]
        child_bid = self.node_to_bid[child]
        assert isinstance(child_bid, dict)
        assert node.field in child_bid
        bid = child_bid[node.field]
        self.node_to_bid[node] = bid
        self.netlist[bid].append((child, node.field))

    def generic_visit(self, node):
        Visitor.generic_visit(self, node)
        child_bids = [self.node_to_bid[child] for child in node.children()]
        if node.node_name not in self.inst_info:
            raise ValueError(f"Missing {node.node_name} in info")
        input_t = self.inst_info[node.node_name]
        for field, child_bid in zip(input_t.field_dict.keys(), child_bids):
            if child_bid is None:
                continue
            assert child_bid in self.netlist
            self.netlist[child_bid].append((node, field))
        bid = self.create_buses(node.type)
        self.node_to_bid[node] = bid

    def visit_Combine(self, node: Combine):
        Visitor.generic_visit(self, node)
        child_bids = [self.node_to_bid[child] for child in node.children()]
        input_t = node.type
        bids = {}
        for field, child_bid in zip(input_t.field_dict.keys(), child_bids):
            if child_bid is None:
                continue
            bids[field] = child_bid
        self.node_to_bid[node] = bids

    def visit_Output(self, node: Output):
        Visitor.generic_visit(self, node)
        child_bid = [self.node_to_bid[child] for child in node.children()][0]
        assert isinstance(child_bid, dict)
        for field, bid in child_bid.items():
            self.netlist[bid].append((node, field))

class CreateInstrs(Visitor):
    def __init__(self, inst_info):
        self.inst_info = inst_info

    def doit(self, dag: IODag):
        self.node_to_instr = {}
        self.run(dag)
        return self.node_to_instr

    def visit_Input(self, node):
        self.node_to_instr[node] = 1

    def visit_Output(self, node):
        Visitor.generic_visit(self, node)
        self.node_to_instr[node] = 2

    def visit_Select(self, node):
        Visitor.generic_visit(self, node)

    def visit_Combine(self, node):
        Visitor.generic_visit(self, node)

    def visit_Constant(self, node):
        pass

    def generic_visit(self, node: DagNode):
        Visitor.generic_visit(self, node)
        if node.node_name not in self.inst_info:
            raise ValueError(f"Need info for {node.node_name}")
        adt = self.inst_info[node.node_name]
        instr_child = list(node.children())[0]
        assert isinstance(instr_child, Constant)
        self.node_to_instr[node] = instr_child.value

class CreateMetaData(Visitor):
    def doit(self, dag):
        self.node_to_md = {}
        self.run(dag)
        return self.node_to_md

    def generic_visit(self, node):
        Visitor.generic_visit(self, node)
        if hasattr(node, "_metadata_"):
            self.node_to_md[node] = node._metadata_


class CreateIDs(Visitor):
    def __init__(self, inst_info):
        self.inst_info = inst_info

    def doit(self, dag: IODag):
        self.i = 0
        self.node_to_id = {}
        self.run(dag)
        return self.node_to_id

    def visit_Input(self, node):
        pass


    def visit_Output(self, node: Output):
        Visitor.generic_visit(self, node)
        child = list(node.children())[0]
        assert isinstance(child, Combine)
        c_children = list(child.children())
        if isinstance(c_children[0], Constant):
            is_bit = True
        else:
            is_bit = False

        if is_bit:
            id = f"i{self.i}"
        else:
            id = f"I{self.i}"
        self.i += 1
        self.node_to_id[node] = id

    def visit_Select(self, node):
        Visitor.generic_visit(self, node)
        child = list(node.children())[0]
        if isinstance(child, Input):
            if node.type == Bit:
                id = f"i{self.i}"
            elif node.type == BitVector[16]:
                id = f"I{self.i}"
            else:
                raise NotImplementedError(f"{node}, {node.type}")
            self.i += 1
            self.node_to_id[child] = id

    def visit_Combine(self, node):
        Visitor.generic_visit(self, node)

    def visit_Constant(self, node):
        pass

    def generic_visit(self, node: DagNode):
        Visitor.generic_visit(self, node)
        if node.node_name not in self.inst_info:
            raise ValueError(f"Need info for {node.node_name}")
        id = f"{self.inst_info[node.node_name]}{self.i}"
        self.node_to_id[node] = id
        self.i += 1


def p(msg, adt):
    print(msg, list(adt.field_dict.items()))

def is_bv(adt):
    return issubclass(adt, (BitVector, Bit))

def flatten_adt(adt, path=()):
    if is_bv(adt):
        return {path: adt}
    elif issubclass(adt, Product):
        ret = {}
        for k in adt.field_dict:
            sub_ret = flatten_adt(adt[k], path + (k,))
            ret.update(sub_ret)
        return ret
    elif issubclass(adt, Tuple):
        ret = {}
        for i in range(len(adt.field_dict)):
            sub_ret = flatten_adt(adt[i], path + (i,))
            ret.update(sub_ret)
        return ret
    else:
        raise NotImplementedError(adt)


class IO_Input_t(Product):
    io2f_16=BitVector[16]
    io2f_1=Bit

class IO_Output_t(Product):
    f2io_16=BitVector[16]
    f2io_1=Bit

class FlattenIO(Visitor):
    def __init__(self):
        pass

    def doit(self, dag: Dag):
        input_t = dag.input.type
        output_t = dag.output.type
        ipath_to_type = flatten_adt(input_t)
        self.node_to_opaths = {}
        self.node_to_ipaths = {}
        self.node_map = {}
        self.opath_to_type = flatten_adt(output_t)

        isel = lambda t: "io2f_1" if t==Bit else "io2f_16"
        real_inputs = [Input(type=IO_Input_t) for _ in ipath_to_type]
        self.inputs = {path: inode.select(isel(t)) for inode, (path, t) in zip(real_inputs, ipath_to_type.items())}

        self.outputs = {}
        self.run(dag)
        return IODag(inputs=real_inputs, outputs=self.outputs.values())

    def visit_Output(self, node: Output):
        Visitor.generic_visit(self, node)
        #ROSS TODO: Outputs should only have one input... It should not have a combine node?? think about both cases.
        print(list(node.type.field_dict.items()))
        for field, child in zip(node.type.field_dict, node.children()):
            child_paths = self.node_to_opaths[child]
            for child_path, new_child in child_paths.items():
                new_path = (field, *child_path)
                assert new_path in self.opath_to_type
                child_t = self.opath_to_type[new_path]
                if child_t == Bit:
                    combine_children = [Constant(type=None, value=None), new_child]
                else:
                    combine_children = [new_child, Constant(type=None, value=None)]
                cnode = Combine(*combine_children, type=IO_Output_t)
                self.outputs[new_path] = Output(cnode, type=IO_Output_t)

    def visit_Combine(self, node: Combine):
        Visitor.generic_visit(self, node)
        adt = node.type
        assert issubclass(adt, (Product, Tuple))
        paths = {}
        for k, child in zip(adt.field_dict.keys(), node.children()):
            child_paths = self.node_to_opaths[child]
            for child_path, new_child in child_paths.items():
                new_path = (k, *child_path)
                paths[new_path] = new_child
        self.node_to_opaths[node] = paths

    def visit_Select(self, node: Select):
        def get_input_node(node, path=()):
            if isinstance(node, Input):
                assert path in self.inputs
                return self.inputs[path]
            elif isinstance(node, Select):
                child = list(node.children())[0]
                return get_input_node(child, (node.field, *path))
            else:
                return None
        input_node = get_input_node(node)
        if input_node is not None:
            self.node_map[node] = input_node
            return

        Visitor.generic_visit(self, node)
        new_children = [self.node_map[child] for child in node.children()]
        new_node = node.copy()
        new_node.set_children(*new_children)
        self.node_to_opaths[node] = {(): new_node}
        self.node_map[node] = new_node

    def generic_visit(self, node: DagNode):
        Visitor.generic_visit(self, node)
        new_children = [self.node_map[child] for child in node.children()]
        new_node = node.copy()
        new_node.set_children(*new_children)
        self.node_to_opaths[node] = {(): new_node}
        self.node_map[node] = new_node



def print_netlist_info(info):
    print("id to instance name")
    for k, v in info["id_to_name"].items():
        print(f"  {k}  {v}")

    print("id_to_Instrs")
    for k, v in info["id_to_instrs"].items():
        print(f"  {k}, {v}")

    print("id_to_metadata")
    for k, v in info["id_to_metadata"].items():
        print(f"  {k}, {v}")

    print("buses")
    for k,v in info["buses"].items():
        print(f"  {k}, {v}")

    print("netlist")
    for bid, v in info["netlist"].items():
        print(f"  {bid}")
        for _v in v:
            print(f"    {_v}")


from lassen.sim import PE_fc as lassen_fc
from metamapper. common_passes import print_dag

def create_netlist_info(dag: Dag, tile_info: dict):
    fdag = FlattenIO().doit(dag)

    def tile_to_char(t):
        if t.split(".")[1]=="PE":
            return "p"
        elif t.split(".")[1]=="MEM":
            return "m"
    node_info = {t:tile_to_char(t) for t in tile_info}

    info = {}
    nodes_to_ids = CreateIDs(node_info).doit(fdag)
    info["id_to_name"] = {id: node.iname for node,id in nodes_to_ids.items()}

    node_to_metadata = CreateMetaData().doit(fdag)
    info["id_to_metadata"] = {nodes_to_ids[node]: md for node, md in node_to_metadata.items()}

    nodes_to_instrs = CreateInstrs(node_info).doit(fdag)
    info["id_to_instrs"] = {id:nodes_to_instrs[node] for node, id in nodes_to_ids.items()}
    
    info["instance_to_instrs"] = {node.iname:nodes_to_instrs[node] for node, id in nodes_to_ids.items() if ("p" in id or "m" in id)}
    for node, md in node_to_metadata.items():
        info["instance_to_instrs"][node.iname] = md


    node_info = {t:fc.Py.input_t for t,fc in tile_info.items()}
    bus_info, netlist = CreateBuses(node_info).doit(fdag)
    info["buses"] = bus_info
    info["netlist"] = {}
    for bid, ports in netlist.items():
        info["netlist"][bid] = [(nodes_to_ids[node], field) for node, field in ports]
    return info


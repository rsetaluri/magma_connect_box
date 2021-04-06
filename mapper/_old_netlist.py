@pytest.mark.parametrize("app", examples_coreir)
def test_netlist(app):
    print("STARTING TEST")
    c = CoreIRContext(reset=True)
    file_name = f"examples/coreir/{app}.json"
    cutil.load_libs(["commonlib"])
    CoreIRNodes = gen_CoreIRNodes(16)
    cmod = cutil.load_from_json(file_name) #libraries=["lakelib"])
    dag = cutil.coreir_to_dag(CoreIRNodes, cmod)
    arch_fc = gen_ALU(16)
    name = "ALU"
    ArchNodes = Nodes("Arch")
    putil.load_from_peak(ArchNodes, arch_fc)
    mapper = Mapper(CoreIRNodes, ArchNodes, lazy=True)
    mapped_dag = mapper.do_mapping(dag, prove_mapping=False)


    node_info = {
        ArchNodes.dag_nodes["ALU"] : 'p',
        CoreIRNodes.dag_nodes["coreir.reg"][0]: 'R',
        CoreIRNodes.dag_nodes["coreir.reg"][1]: 'R',
        #CoreIRNodes.peak_nodes["corebit.reg"]: 'r'
    }
    netlist_info = CreateNetlist(node_info).doit(mapped_dag)
    print("N")
    for k, v in netlist_info["netlist"].items():
        print(f"  {k}")
        for _v in v:
            print(f"    {_v}")

    print("B")
    for k,v in netlist_info["buses"].items():
        print(f"  {k}, {v}")

    class CreateNetlist(Visitor):

        def __init__(self, node_info):
            self.node_info = node_info

        # Translate an ADT to a dictionary of names and widths
        def T_to_nets(self, T, input=False):
            print(T)
            if T is BitVector[16]:
                net_id = f"e{self.net_id}"
                self.net_to_sp[net_id] = []
                self.buses[net_id] = 16
                self.net_id += 1
                if input:
                    I_id = f"I{self.node_id}"
                    self.node_id += 1
                    self.net_to_id[net_id] = I_id
                    self.net_to_sp[net_id].append((I_id, "i2f"))
                return net_id
            elif T is Bit:
                net_id = f"e{self.net_id}"
                self.net_to_sp[net_id] = []
                self.buses[net_id] = 1
                self.net_id += 1
                if input:
                    I_id = f"i{self.node_id}"
                    self.node_id += 1
                    self.net_to_id[net_id] = I_id
                    self.net_to_sp[net_id].append((I_id, "i2f"))
                return net_id
            elif issubclass(T, Tuple):
                d = {}
                for i, subT in T.field_dict.items():
                    d[i] = self.T_to_nets(subT, input)
                return d
            else:
                raise NotImplementedError(str(T))

        def doit(self, dag):
            print_dag(dag)
            self.net_id = 0
            self.node_id = 0

            self.buses = {}
            self.node_to_nets = {}  # Recursive structure on select paths
            self.net_to_id = {}
            self.node_to_id = {}
            self.net_to_sp = {}
            self.run(dag)
            id_to_name = dict(
                I0="io_in",
            )
            inst_to_instr = dict(
                I0=1,
            )
            netlist = dict(
                e0=[("I0", "io2f_16"), ("p0", "data0"), ("p0", "data1")],
            )
            buses = dict(
                e0=16,
            )

            for k, v in self.node_to_nets.items():
                print(k, v)
            return dict(
                id_to_instr=None,
                inst_to_instr=None,
                netlist=self.net_to_sp,
                buses=self.buses
            )

        def generic_visit(self, node):
            Visitor.generic_visit(self, node)

            # Create a node_id
            if type(node) not in self.node_info:
                raise ValueError(f"Cannot handle {node}")
            node_id = f"{self.node_info[type(node)]}{self.node_id}"
            self.node_id += 1
            self.node_to_id[node] = node_id

            # Get the child name -> nets
            fields = list(node.nodes.peak_nodes[node.node_name].Py.input_t.field_dict)
            for field, child in zip(fields, node.children()):
                if isinstance(child, Constant):
                    continue
                net_id = self.node_to_nets[child]
                self.net_to_sp[net_id].append((node_id, field))

            # Create output nets and add to net_to_sp
            net_info = self.T_to_nets(node.type)
            self.node_to_nets[node] = net_info
            for field, net_id in net_info.items():
                assert isinstance(net_id, str)
                self.net_to_sp[net_id].append((node_id, field))
                self.net_to_id[net_id] = node_id

        def visit_Input(self, node):
            net_info = self.T_to_nets(node.type, input=True)
            self.node_to_nets[node] = net_info

        def visit_Select(self, node):
            Visitor.generic_visit(self, node)
            child = node.children()[0]
            n2n = self.node_to_nets[child]
            self.node_to_nets[node] = n2n[node.field]

        def visit_Constant(self, node):
            pass

        def visit_Output(self, node):
            Visitor.generic_visit(self, node)
            for (field, T), child in zip(node.type.field_dict.items(), node.children()):
                net_id = self.node_to_nets[child]
                node_id = f"o{self.node_id}"
                self.node_id += 1
                self.net_to_sp[net_id].append((node_id, "f2i"))

proc query_module_name {name} {
    set res [exec python tools/symbol_query_interface_cli.py garnet_symbol_table.json --module $name];
    return $res
}

proc query_instance_name {name} {
    set res [exec python tools/symbol_query_interface_cli.py garnet_symbol_table.json --instance $name];
    return $res
}

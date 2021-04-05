import argparse
import enum
import sys

import magma as m
from magma.symbol_table import SymbolTable
from magma.symbol_table_utils import SymbolQueryInterface


class _QueryArgumentError(Exception):
    pass


class _ReadFileError(Exception):
    pass


class _SymbolTableParseError(Exception):
    pass


class _ExitCodes(enum.Enum):
    SUCCESS = 0
    UNCAUGHT_EXCEPTION = 200 #enum.auto()
    COMMAND_LINE_ARGUMENT_ERROR = enum.auto()
    READ_FILE_ERROR = enum.auto()
    SYMBOL_TABLE_PARSE_ERROR = enum.auto()
    SYMBOL_TABLE_QUERY_KEY_ERROR = enum.auto()
    SYMBOL_TABLE_INLINED_LEAF_INSTANCE_ERROR = enum.auto()


def _exit_code_str():
    s = "\n".join(f"    {code.value}: {code.name}" for code in _ExitCodes)
    return "exit codes:\n" + s


def _get_table(filename):
    try:
        with open(filename, "r") as f:
            s = f.read()
    except BaseException as e:
        sys.stderr.write(f"Error reading file '{filename}': {repr(e)}\n")
        raise _ReadFileError() from None
    try:
        return SymbolTable.from_json(s)
    except BaseException as e:
        sys.stderr.write(f"Error parsing file '{filename}': {repr(e)}\n")
        raise _SymbolTableParseError() from None


def _command_to_function(cmd):
    if cmd == "module":
        return SymbolQueryInterface.get_module_name
    if cmd == "instance":
        return SymbolQueryInterface.get_instance_name
    raise NotImplementedError(cmd)


def _get_query(args):
    non_empty_args = {k: v for k, v in vars(args).items() if v is not None}
    if len(non_empty_args) != 1:
        raise _QueryArgumentError()
    non_empty_args = list(non_empty_args.items())[0]
    cmd, arg = non_empty_args
    return _command_to_function(cmd), (arg,)


def _main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=_exit_code_str())
    parser.add_argument("file", type=str, help="symbol table (json) filename")
    parser.add_argument("--module", type=str, help="module name query")
    parser.add_argument("--instance", type=str, help="instance name query")
    try:
        args = parser.parse_args()
    except BaseException as e:
        sys.stderr.write(f"Error parsing command line arguments: {repr(e)}\n")
        sys.exit(_ExitCodes.COMMAND_LINE_ARGUMENT_ERROR.value)
    query_keys = set(["module", "instance"])
    query_args = argparse.Namespace(**{k: getattr(args, k) for k in query_keys})
    try:
        query = _get_query(query_args)
    except _QueryArgumentError:
        sys.exit(_ExitCodes.COMMAND_LINE_ARGUMENT_ERROR.value)
    fn, query_args = query
    try:
        table = _get_table(args.file)
    except _ReadFileError:
        sys.exit(_ExitCodes.READ_FILE_ERROR.value)
    except _SymbolTableParseError:
        sys.exit(_ExitCodes.SYMBOL_TABLE_PARSE_ERROR.value)
    query_ifc = SymbolQueryInterface(table)
    try:
        return fn(query_ifc, *query_args)
    except KeyError as e:
        sys.stderr.write(f"Query error: key error: {repr(e)}\n")
        sys.exit(_ExitCodes.SYMBOL_TABLE_QUERY_KEY_ERROR.value)
    except SymbolQueryInterface.InlinedLeafInstanceError:
        sys.stderr.write("Query error: leaf of query inlined\n")
        sys.exit(_ExitCodes.SYMBOL_TABLE_INLINED_LEAF_INSTANCE_ERROR.value)


if __name__ == "__main__":
    try:
        res = _main()
    except Exception as e:
        sys.stderr.write(f"Uncaught exception: {repr(e)}\n")
        sys.exit(_ExitCodes.UNCAUGHT_EXCEPTION.value)
    sys.stdout.write(res)

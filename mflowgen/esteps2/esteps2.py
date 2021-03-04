#=========================================================================
# easysteps.py (esteps2 for now)
#=========================================================================
# Author : S. Richardson
# Date   : February, 2021

import os
import re
import sys
from mflowgen.components.step import Step

# Persistent storage for todo list
_todo    = {}   ;# Connections waiting to be made, used only by easysteps
_extnodes= []   ;# List of extension nodes, used only by easysteps

# C/D/EStep could be ?improved? with...what? decorators? kwargs?

def CStep(graph, stepdir, successors, DBG=0):
    "E.g. rtl = CStep(g, '/../common/rtl', ['synth'])"
    return _add_step_with_handle(graph, stepdir, successors, 'custom', DBG)

def DStep(graph, stepdir, successors, DBG=0):
    return _add_step_with_handle(graph, stepdir, successors, 'default', DBG)

def EStep(graph, stepdir, successors, DBG=0):
    return _add_step_with_handle(graph, stepdir, successors, 'extension', DBG)



def _add_step_with_handle(graph, stepdir, successors, which, DBG=0):
    '''
        # Build a step using the indicated step-defining directory.
        # Add names of successors to a list for later processing.
    '''
    DBG=1 # for now, ABD (Always Be Debuggin)

    # Define the step
    assert which in ['custom','default','extension']
    if DBG: print(f"Adding {which} step '{stepdir}' -> '{successors}'")
    if which == 'default':
        step_obj  = Step( stepdir, default=True)
    else:
        frame     = sys._getframe(2)
        this_file = os.path.abspath( frame.f_globals['__file__'] )
        this_dir  = os.path.dirname( this_file )
        step_dir  = this_dir + '/' + stepdir
        step_obj  = Step( step_dir, default=False)

    # Add step to graph
    graph.add_step(step_obj)


#     # Convert 'successors' string into a list
#     # Example string: '  genlibdb,pt_signoff,    debugcalibre' )
#     successors = re.sub(r'\s+', '', successors) ;# Eliminate whitespace
#     if successors == '': successors = []
#     else:                successors = successors.split(',')
# 
#     # Build todo list
#     _todo[step_obj] = successors


    econnect(step_obj, successors)



    # Extension?
    if which == 'extension':
        _extnodes.append(step_obj)  ;# Mark this step as an "extend" step

    if DBG: print('')
    return step_obj


def econnect(from_step, to_steps, DBG=1):

    # Ensure that todo list exists
    try: _todo[from_step]
    except KeyError: _todo[from_step] = []

    # Convert 'to_steps' string into a list
    # Example string: '  genlibdb,pt_signoff,    debugcalibre' )
    to_steps = re.sub(r'\s+', '', to_steps) ;# Eliminate whitespace
    if to_steps == '': return
    to_list = to_steps.split(',')

    # Build todo list
    for to_stepname in to_list:
        _todo[from_step].append(to_stepname)
        




def connect_outstanding_nodes(graph, DBG=0):
    '''
    # construct.py should call this method after all steps have been built,
    # to clear out the todo list.
    '''
    DBG=1
    if DBG: print("PROCESSING CONNECTIONS IN TODO LIST")

    # Quick shortcut to avoid further problems
    if _todo == {}: return

    # Build dictionaries that map steps to names
    # e.g. step_dict['adk'] = <mflowgen.components.step.Step object at 0x7f113f1f4490>
    # step_dict_rev[<mflowgen.components.step.Step object at 0x7f113f1f4490>] = 'adk'
    frame = sys._getframe(1)
    if DBG: print("Looking for step defs in caller")
    (step_dict,step_dict_rev) = _build_step_dicts(frame, DBG)

    for from_step in _todo:

        from_name = step_dict_rev[from_step]
        if DBG: print(f'\nPROCESSING step {from_name}')

        # Must make shallow copy b/c we may be deleting elements in situ
        to_list = _todo[from_step].copy() ;

        for to_name in to_list:
            if DBG: print(f"  CONNECTING {from_name} -> {to_name}")

            # to_node = _findvar(frame, to_name, DBG)

            to_node = step_dict[to_name]

            # If "from" is an "extension" node, connect all "from" outputs as "to" inputs
            if from_step in list(_extnodes):
              if DBG: print('    Extnode: connecting all outputs to dest node')
              to_node.extend_inputs( from_step.all_outputs() )

            # Connect "from" -> "to" nodes
            graph.connect_by_name(from_step, to_node)
            # if DBG: print(f'    CONNECTED {from_step} -> {to_name}')
            # if DBG: print('')
            _todo[from_step].remove(to_name)

            # if DBG: print(f'    REMOVED from todo list: {from_step} -> {to_name}\n')

def _build_step_dicts(frame, DBG=0):
    """
    Build a dictionary that maps steps to names
    e.g. step_dict['adk'] = <mflowgen.components.step.Step object at 0x7f113f1f4490>
    """

    # Get a handle on the step type using first item in the populated _todo list
    # e.g. step_type=<class 'mflowgen.components.step.Step'>
    step_type = type( list(_todo.keys())[0] )

    # Search calling frame for steps, build a dictionary
    step_dict = {}
    step_dict_rev = {}
    for lname in frame.f_locals:
        lval = frame.f_locals[lname]
        if type(lval) == step_type:
            if DBG>9: print(f"  FOUND step {lname:20} = {lval}")
            step_dict[lname]    = lval
            step_dict_rev[lval] = lname

    # Sort main dictionary by key why not
    step_dict = dict(sorted(step_dict.items()))
    if DBG>1:
        print('Sorted list of steps')
        for k in step_dict: print(f"  {k:20} = {step_dict[k]}")

    return (step_dict, step_dict_rev)


#       reorder(place,
#               'before main.tcl: conn-aon-cells-vdd.tcl',
#               'after  main.tcl: check-clamp-logic-structure.tcl'
#               'last           : check-clamp-logic-structure.tcl'
#       )
# 
#       reorder(cts,
#               'first: conn-aon-cells-vdd.tcl',
#               'last:  check-clamp-logic-structure.tcl'
#       )



def reorder(step, *args, DBG=0):
    DBG=1
    order = step.get_param('order')

    for a in args:
        # Separate "where" ('begin') and "what" ('foo.tcl')
        # where e.g. a="begin : conn-aon-cells-vdd.tcl"
        (where,what) = a.split(':')

        # Strip out all whitespace (trust me)
        where = re.sub(r'\s+', '', where)
        what = re.sub(r'\s+', '', what)
        if DBG>9: print(f'where="{where}", what="{what}" foozey')

        # 'where' can be one of:
        #    "first"
        #    "last"
        #    "before <filename>"
        #    "after <filename>"
        #    "then"

        if where == "first":
            if DBG: print(f"reorder: add '{what}' as FIRST in order list")
            order.insert( 0, what ) # add here

        elif where == "last":
            if DBG: print(f"reorder: add '{what}' as LAST in order list")
            order.append(what)

        elif where[0:5] == "after":
            filename = where[5:]
            if DBG: print(f"reorder: add '{what}' AFTER '{filename}'")
            read_idx = order.index( filename )
            order.insert(read_idx + 1, what)

        elif where[0:6] == "before":
            filename = where[6:]
            if DBG: print(f"reorder: add '{what}' BEFORE '{filename}'")
            read_idx = order.index( filename )
            order.insert(read_idx - 1, what)

        elif where == "then":
            if DBG: print(f"reorder: add '{what}' AFTER '{prev}'")
            read_idx = order.index( prev )
            order.insert(read_idx + 1, what)

        elif where == "remove" or where == 'delete':
            if DBG: print(f"reorder: remove '{what}' from list")
            order.remove(what)

        else:
            assert False, \
                print(f"**ERROR bad keyword '{where}'")

        prev = what

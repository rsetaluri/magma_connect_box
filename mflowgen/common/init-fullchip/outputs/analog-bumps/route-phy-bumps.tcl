proc route_phy_bumps {} {
    set TEST 0; # Set to '1' to debug interactively w/ gui; else must be 0
    
    if {$TEST} {
        # Delete previous attempts
        editDelete -net net:pad_frame/CVDD
        editDelete -net net:pad_frame/CVSS
    }

    puts "@file_info: PHY bumps 0: add nets CVDD, CVSS etc."
    source inputs/analog-bumps/build-phy-nets.tcl
    # source ../../pad_frame/3-netlist-fixing/outputs/netlist-fixing.tcl
    # source /sim/steveri/soc/components/cgra/garnet/mflowgen/common/fc-netlist-fixing/outputs/netlist-fixing.tcl
    if {$TEST} {
        source inputs/analog-bumps/build-phy-nets.tcl
        source inputs/analog-bumps/route-phy-bumps.tcl
    }

    # FIXME I guess these should never have been assigned in the first place...!
    puts "@file_info: PHY bumps 0.1: remove prev bump assignments"
    foreach net {CVDD CVSS AVDD AVSS} {
        foreach bumpname [dbGet [dbGet -p2 top.bumps.net.name $net].name] { 
            if { $bumpname == 0x0 } { continue }
            echo unassignBump -byBumpName $bumpname
            unassignBump -byBumpName $bumpname
        }
    }

    puts "@file_info: PHY bumps 1: route bump S1 to CVDD"
    # connect_bump CVDD *26.3 "1100 4670  1590 4800" ; # Cool! but it runs over icovl cells
    connect_bump CVDD *26.3 "1100 4670  1590 4750"; # munch better

    puts "@file_info: PHY bumps 2: route bump S2 to CVSS"
    connect_bump CVSS *26.4 "770 4800  1590 4900"

    puts "@file_info: PHY bumps 3: Remainder of CVDD"
    sleep 1; bump_connect_diagonal   CVDD *26.3 *25.4 *24.5 *23.6 *22.7
    sleep 1; bump_connect_orthogonal CVDD *23.5 *23.6
    sleep 1; bump_connect_orthogonal CVDD *22.6 *22.7 *22.8 *22.9

    puts "@file_info: PHY bumps 3: Remainder of CVSS"
    sleep 1; bump_connect_diagonal   CVSS Bump_629.25.5 Bump_654.26.4
    sleep 1; bump_connect_orthogonal CVSS *25.5 *25.6 *25.7 *25.8
    sleep 1; bump_connect_orthogonal CVSS *25.8 *24.8 *23.8
    sleep 1; bump_connect_orthogonal CVSS *23.8 *23.7
    sleep 1; bump2wire_up  CVSS Bump_631.25.7 Bump_657.26.7
    sleep 1; bump2wire_up  CVSS Bump_659.26.9

    puts "@file_info: PHY bumps 4: ext_Vcm and ext_Vcal"
    # DP3 26.15 => ext_Vcm
    # DP4 26.26 => ext_Vcal
    connect_bump2 ext_Vcal *26.16
    connect_bump2 ext_Vcm  *26.15
}
#    sleep 1; bump_connect_orthogonal CVSS *25.7  ERROR?


# Procedure for routing PHY bumps
proc fcroute_phy { route_style bump args } {
    setFlipChipMode -route_style $route_style
    setFlipChipMode -connectPowerCellToBump true

    # For phy bump routing this must be TRUE
    setFlipChipMode -honor_bump_connect_target_constraint true

    # setFlipChipMode -route_style 45DegreeRoute
    # setFlipChipMode -route_style manhattan

    set save_selected [get_db selected]; # SAVE
    deselectAll; select_obj $bump; sleep 1
    fcroute -type signal -selected \
        -layerChangeBotLayer AP \
        -layerChangeTopLayer AP \
        -routeWidth 30.0 \
        {*}$args
    deselectAll; select_obj $save_selected; # RESTORE
}




# Connect bump 'b' to net 'net'
proc connect_bump { net b args } {
    # Connect bump 'b' to net 'net'
    # Can include an optional blockage box to direct the routing
    # Examples:
    #     connect_bump CVDD *26.3
    #     connect_bump CVSS *26.4 "770 4800  1590 4900"

    set blockage "none"; if {[llength $args]} { set blockage $args }

    set TEST 0; # Set to '1' to debug interactively w/ gui; else must be 0
    if {$TEST} {
        # Removes (all) prev routes related to $net
        editDelete -net net:pad_frame/$net

        # And/or can use this command to delete ALL RDL wires and start with a clean slate:
        # deselectAll; editSelect -layer AP; deleteSelectedFromFPlan; sleep 1

        # Cut'n' paste one of these for interactive test
        set b *26.3; set net CVDD; set blockage "none"
        set b *26.4; set net CVSS; set blockage "770 4800  1590 4900"
        set net ext_Vcm; set b *26.15; set blockage "none"
    }
    echo "@file_info b=$b net=$net blockage=$blockage"
    # Get targeted bump, net, pad, and blockage
    # Note we use ANAIOPAD_$net as the pad; we may want to change this at some 
    # point and e.g. route both CVDD and CVSS bumps to different ports on e.g. ANAIOPAD_CVDD
    # set b [dbGet top.bumps.name *26.3]; # Bump_653.26.3 (row 26, col 3)
    set pad ANAIOPAD_$net
    set b [dbGet top.bumps.name $b]
    echo "@file_info b=$b pad=$pad"

    # Assign the bump to the net; then
    # show flight line resulting from default assignment
    if {$TEST} { unassignBump -byBumpName $b }

    # if net does not exist yet, build it!
    # For now at least, all nets are power nets (?)
    set n [dbGet -p top.nets.name $net]
    if { $n == 0 } {
        # FIXME what if it's a ground net...hmmmm???
        # Maybe search for substring "ss"??
        addNet $net  -power -physical
    }
    # addNet ext_Vcal -power -physical; # V2T bias voltage

    assignPGBumps -nets $net -bumps $b
    viewBumpConnection -bump $b; sleep 1

    # Find and assign more precise bump target
    findPinPortNumber -instName $pad -netName $net; # ANAIOPAD_CVDD:TACVDD:1
    set ppn [findPinPortNumber -instName $pad -netName $net]
    set pin_name [lindex [split $ppn ":"] 1]
    set port_num [lindex [split $ppn ":"] 2]
    echo addBumpConnectTargetConstraint -bump $b \
        -instName $pad \
        -pinName $pin_name \
        -portNum $port_num

    addBumpConnectTargetConstraint -bump $b \
        -instName $pad \
        -pinName $pin_name \
        -portNum $port_num

    # Verify constraint for bump $b, show new flight line
    dbGet [dbGet -p top.bumps.name $b].props.??
    viewBumpConnection -bump $b; sleep 1

    # Use optional blockage to direct the routing. Useful blocks may include
    #   "960 4670 1480 4730"    "770 4800 1630 4900"    "770 4800 1590 4900"
    if { $blockage != "none" } {
        echo create_route_blockage -layer AP -box $blockage -name temp
        create_route_blockage -layer AP -box $blockage -name temp
        redraw; sleep 1
    }

    # Route the bump, then delete temporary blockage and flightlines
    fcroute_phy manhattan $b
    if { $blockage != "none" } { deleteRouteBlk -name temp }
    viewBumpConnection -remove
}




# set TEST 1; if {$TEST} { connect_bump ext_Vcm *26.15 }



# Useful tests for proc connect_bump
if {0} {
    # Cut'n'paste for interactive testing
    deselectAll; select_obj [ get_db markers ]; deleteSelectedFromFPlan
    deselectAll; editSelect -layer AP; deleteSelectedFromFPlan; sleep 1

    unassignBump -byBumpName Bump_653.26.3
    connect_bump CVDD *26.3
    connect_bump CVSS *26.4 "770 4800  1590 4900"
}

# Connect bump 'b' to net 'net'
proc connect_bump2 { net b args } {
    set bump [dbGet top.bumps.name $b]; # this way arg can be wildcard e.g. '*26.15'

    # proc fcroute_phy_net
    proc get_term_net { inst term } {
        # Find the net attached to the given term on the given inst
        # Example: [get_term_net ANAIOPAD_ext_Vcm AIO]
        set iptr [dbGet -p top.insts.name $inst]; # dbGet $iptr.??
        set tptr [dbGet -p $iptr.instTerms.name *$term]; # dbGet $iptr.??
        dbGet $tptr.net.name
    }

    set TEST 0; if {$TEST} {
        # Identify pad, net, terminal, bump
        set net ext_Vcal; set bump Bump_666.26.16; # Do this one FIRST
        set net ext_Vcm; set bump Bump_665.26.15; # Do this one second
    }
    set pad ANAIOPAD_$net; set term AIO


    # Remove previous attempt if necessary
    if {0} {
        editDelete -net net:pad_frame/$net
        unassignBump -byBumpName $bump
        detachTerm $pad $term
        get_term_net $pad $term; # Should be null
        deleteNet $net
    }

    # Build the new net
    # addNet ext_Vcm -power -physical
    # addNet ext_Vcal -power -physical
    set n [dbGet top.nets.name $net]
    if {$n == 0} {
        # addNet $net -power -physical; # ? this one? or...?
        addNet $net; # I mean...it's a power net but not a power net?
    }

    # Pretty sure this did nothing good
    # globalNetConnect ext_Vcm -netlistOverride -pin AIO -singleInstance ANAIOPAD_ext_Vcm
    # globalNetConnect ext_Vcal -netlistOverride -pin AIO -singleInstance ANAIOPAD_ext_Vcal

    # Attach net to appropriate terminal on pad
    get_term_net $pad $term; # First time should be null (unassigned)
    attachTerm $pad $term $net
    get_term_net $pad $term; # Should be $net now
    # Assert {[get_term_net $pad $term] == $net}


    # Assign bump to net---try signal first
    # assignSigToBump -bumps $bump -net $net; 
    # **ERROR: (IMPSIP-7356): Signal net 'ext_Vcm' is dangling.
    # NOPE breaks if use signal

    # Assign bump to net as power bump
    assignPGBumps -nets $net -bumps $bump
    # **WARN: (IMPDB-1291):   Top cell power port 'ext_Vcm' is connected to a non-power net 'ext_Vcm'.  The type of this net will be changed to POWER net.
    # **WARN: (IMPSYC-1265):  FTerm was not found for net 'ext_Vcm'. 'ext_Vcm' has been created.
    # **WARN: (IMPSIP-7355):  PG net 'ext_Vcm' is dangling.
    viewBumpConnection -bump $bump; # See if we got a good flight line
    redraw; sleep 1; # So flight line will show up during script execution

    # Assign to specific port; apparently not necessary at this point?
    # findPinPortNumber -instName $pad -netName $net; # ANAIOPAD_ext_Vcm:AIO:1
    # set ppn [findPinPortNumber -instName $pad -pinName $net]
    # set pin_name [lindex [split $ppn ":"] 1]
    # set port_num [lindex [split $ppn ":"] 2]
    # echo addBumpConnectTargetConstraint -bump $bump \
        #     -instName $pad -pinName $pin_name -portNum $port_num
    # viewBumpConnection -bump $bump; # See if we got a good flight line

    # route it
    fcroute_phy manhattan $bump
    viewBumpConnection -remove
}

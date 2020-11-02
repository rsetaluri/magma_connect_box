#!/bin/bash

# GLOBALS
DESIGN=full_chip ; # Someday maybe this will be a command-line parm
# (currently unused i think...)

########################################################################
# Default CI_DIR for each host
# FIXME this would work better as a case statement, no?
CI_DIR=/proj/forward/CI ;  # For VDE
[ `hostname` == "r7arm-aha" ] && CI_DIR=/build/CI ; # for ARM
# kiwi is used for debugging the script
[ `hostname` == "kiwi" ]      && CI_DIR=/tmp/deleteme.buildchip.CI
[ `hostname` == "kiwi" ]      && test -e $CI_DIR || mkdir -p $CI_DIR

########################################################################
# Where this script lives
scriptdir=${0%/*} ; # Similar to csh $0:h
[ "$scriptdir" == "$0" ] && scriptdir="."
script_home=`cd $scriptdir; pwd`

########################################################################
# HELP
cmd=$(basename $0)
function Help {
    cat <<EOF

Description: Manual CI for garnet full_chip build

Usage:
   $cmd [ OPTIONS ]

CI build directory:
   kiwi: /tmp/deleteme.buildchip.CI/full_chip.<n>
   vde:  /proj/forward/CI/full_chip.<n>
   arm7: /build/CI/full_chip.<n>

Options:
    '--retry <dir>' attempts to restart an existing failed build <dir>
    (Aliases for --retry include --restart, --continue, --cont ...)

    '--history'       build history
    '--status all'    show status of all builds
    '--status latest' status of latest build only (default)
    '--logs'          show log of latest build

Examples:
   # Build full_chip in e.g. new dir "/build/CI/full_chip.23"
   $cmd

   # Retry failed build in dir "/build/CI/full_chip.117"
   $cmd --retry /build/CI/full_chip.117

EOF
}

########################################################################
# command-line args

# defaults
STATUS_ACTION=latest
ACTION=new
VERBOSE=

while [ $# -gt 0 ] ; do
    case "$1" in
        -v|--verbose) VERBOSE=true ;;
        -q|--quiet)   VERBOSE= ;;
        -h|--help)    Help; exit ;;
        
        # retry, restart, cont, continue...
        --re*)   ACTION=old; shift; build_dir=$1 ;;
        --cont*) ACTION=old; shift; build_dir=$1 ;;
        --hist*) ACTION=history; ;;
        --log*)  ACTION=logs; ;;
        
        --status) ACTION=status;
                  if expr "$2" : '[^-]' > /dev/null; then
                      STATUS_ACTION=$2; shift; # 'latest' or 'all'
                  fi ;;

        *) echo "**ERROR: Unrecognized command-line arg '$1'"; Help; exit 13; ;;
    esac
    shift
done
[ "$VERBOSE" ] && echo ACTION=$ACTION

if [ "$ACTION" == "history" ]; then
    # Example: bt --hist
    #   /tmp/deleteme.buildchip.CI/full_chip.*/buildchip.log
    #     Oct20 full_chip.2: **ERROR: Failed in LVS
    #     Oct20 full_chip.1: **ERROR: Failed in LVS
    #     Oct16 full_chip.0: **ERROR: Failed in LVS

    [ "$VERBOSE" ] && echo CI_DIR=$CI_DIR

    echo "$CI_DIR/full_chip.*/buildchip.log"
    for f in `\ls -t $CI_DIR/full_chip.*/buildchip.log`; do
        timesec=`stat $f -c %Y`
        # filedate=`date -d@$timesec +"%Y-%b-%d"` ; # 2020-Oct-20
        filedate=`date -d@$timesec +"%b%d"`       ; # Oct20
        df=`dirname $f`; bdf=`basename $df`
        echo -n "  $filedate $bdf: "
        grep . $f | tail -1 ; # Last non-null line
    done
    echo ""
    exit
fi

########################################################################
# --logs :: if requested, emit status and exit
hline39="======================================="
hline78=$hline39$hline39
if [ "$ACTION" == "logs" ]; then
    for f in `\ls -t $CI_DIR/full_chip.*/buildchip.log`; do
        echo $hline78
        echo "CMD: tail -40 $f"
        echo "Full log: less $f"
        echo ''
        tail -40 $f
        echo ''
        break ; # Break means we only do the latest log
    done
    exit
fi

########################################################################
# --status :: if requested, emit status and exit
if [ "$ACTION" == "status" ]; then
    [ "$VERBOSE" ] && echo STATUS_ACTION=$STATUS_ACTION
    [ "$VERBOSE" ] && echo CI_DIR=$CI_DIR
    # for f in `\ls -t /build/CI/full_chip.*`; do
    for f in `\ls -t $CI_DIR/full_chip.*/buildchip.log`; do
        echo tail $f

        # egrep '\<FAIL\>|\*\*ERROR' $f | sed 's/^/    /' | grep -v echo | tail
        # egrep '\<PASS/>' $f | tail -1 | sed 's/^/    /'
        # tail $f | grep . | tail -1
        tail $f | grep . | sed 's/^/    /'

        echo ''
        # DONE if only want status of latest build
        # STATUS_ACTION should be either "latest" or "all"
        [ "$STATUS_ACTION" == "latest" ] && break
    done
    exit

fi

# Fail early, fail often I guess
if [ `hostname` == "r7arm-aha" ]; then
    if ! [ "$USER" == "buildkite-agent" ]; then
        echo "**ERROR: you are not buildkite-agent, this will not work"
        exit 13
    fi
fi

# FIXME should maybe check and err if `basename $build_dir` != $CI_DIR
# if [ "$ACTION" == "old" ]; then CI_DIR=$(dirname $build_dir)

echo "Using CI directory CI_DIR='$CI_DIR'"
echo ""

########################################################################
# Find global CI log dir responsible for coordinating all the builds,
# e.g. "/build/CI/full_chip.HIST"
if [ "$ACTION" == "new" ]; then

    ########################################################################
    # Look at existing builds to find next-seq no. for this new build

    # E.g. $CI_DIR=/build/CI
    if ! test -e $CI_DIR; then
        echo "WARNING did not find design dir '$CI_DIR'"
        echo "Is this your first time?"
        echo "I will build it for you..."
        echo "    mkdir -p $CI_DIR"; mkdir -p $CI_DIR
    fi

    # E.g. ls $CI_DIR => full_chip.0,full_chip.1...
    pushd $CI_DIR >& /dev/null
        n=$(\ls -d full_chip.* |&
            \egrep "^full_chip.[0-9]*" | # full_chip.{0,1,83,112...}
            sed "s|^full_chip.||" |      # {0,1,83,112...}
            sort -n | tail -1)           # 112
        # echo $n
    popd >& /dev/null

    # E.g. build='full_chip.113'
    build=full_chip.0
    [ "$n" ] && build=full_chip.$((n+1))   # E.g. 'full_chip.14'

    build_dir=$CI_DIR/$build  # E.g. '/build/CI/full_chip.14'
    if test -e $build_dir; then
        echo "WARNING '$build_dir' already exists (it shouldn't)."
    else
        mkdir -p $build_dir
    fi
    
    ########################################################################
    # Build the chip
    log=$build_dir/buildchip.log  

    echo ""
    echo "Calling subcommand:"
    echo "    buildchip.sh --new $build_dir \\"
    echo "        |& tee -a $log"; echo ""

    ########################################################################
    echo '----------------------------------------' >> $log
    printf "`date`\n\n" >> $log
    $script_home/buildchip.sh --new $build_dir |& tee -a $log
    ########################################################################

elif  [ "$ACTION" == "old" ]; then

    # build_dir should have been specified on command line
    # FIXME/TODO add to usage / help:
    # build_dir can be specified as one of three ways
    #    bt --retry /tmp/deleteme.buildchip.CI/full_chip.7
    #    bt --retry full_chip.7
    #    bt --retry 7

    build_num=` expr $build_dir : '^[^0-9]*\([0-9]*\)'` ; # E.g. "7"
    build=full_chip.$build_num            ; # E.g. 'full_chip.7'
    build_dir=$CI_DIR/$build  ; # E.g. '/build/CI/full_chip.7'

    # basename $build_dir -- to find "full_chip.7"
    # log=$logdir/full_chip.7 or something

    cd $build_dir
    if ! test -e $build_dir; then 
        echo "**ERROR: Cannot find specified build dir '$build_dir'"; Help; exit 13
    fi
    
    ########################################################################
    # (Re)build the chip
    log=$build_dir/buildchip.log  
    echo ""
    echo "Calling subcommand:"
    echo "    buildchip.sh --retry $build_dir \\"
    echo "        |& tee -a $log"; echo ""

    ########################################################################
    echo '----------------------------------------' >> $log
    printf "`date`\n\n" >> $log
    $script_home/buildchip.sh --retry $build_dir |& tee -a $log
    ########################################################################
fi

exit

##############################################################################
##############################################################################
##############################################################################

# UNIT TESTS on kiwi

alias bt='/nobackup/steveri/github/garnet/mflowgen/bin/bigtest.sh'
cd /tmp/deleteme.buildchip.CI
i=0

c; log=bt.log.$((i++)); echo "less $log"; bt |& tee $log
ls

bt --retry /tmp/deleteme.buildchip.CI/full_chip.2
bt --retry full_chip.2
bt --retry 2

bt --status
bt --status all
bt --status latest
bt --logs


# UNIT TESTS on arm7

# Update garnet branch(es)
# (as steveri)
garnet=/sim/steveri/soc/components/cgra/garnet
(cd $garnet; git checkout master; git pull)
(cd $garnet; git pull)
(cd $garnet; git branch)
(cd $garnet; git checkout civde2)

# Must be agent
xterm -e sudo su buildkite-agent &
source ~steveri/env/bashrc
xtitle agent


# setup
garnet=/sim/steveri/soc/components/cgra/garnet
alias bt='$garnet/mflowgen/bin/bigtest.sh'
cd /build/CI
i=0

# Help
bt --help

# Run bigtest, output to bt.log.$i
echo $i
c; log=bt.log.$((i++)); echo "less $log"; bt |& tee $log | less

# View latest build: bt --view latest?
ls -l `ls -td /build/CI/full_chip.* | tail -1`
c; bt --status
c; bt --status all



# ########################################################################
# # bt --status latest
# latest=`\ls -td /build/CI/full_chip.* | tail -1`
# echo latest=$latest ; # E.g. latest=/build/CI/full_chip.0/
# 
# egrep 'PASS|FAIL|ERROR' $build/buildchip.log
#   # ***ERROR: Looks like dir '/build/CI/full_chip.0' has only 92G
#   # ***ERROR: Dir '/build/CI/full_chip.0' needs at least 100G to continue
#   # **ERROR: Failed in LVS
# 
# 
# ########################################################################
# # bt --status all
# for f in `\ls -t /build/CI/full_chip.*`; do
#     echo '------------------------------------------------------------'
#     echo STATUS $f
#     egrep 'PASS|FAIL|ERROR' $f
# done





# DONE sourcing '/sim/steveri/soc/components/cgra/garnet/mflowgen/bin/setup-buildkite.sh' ...
# Checking out last known good version #adad99d
# fatal: Unable to create '/sim/steveri/soc/.git/modules/components/cgra/garnet/index.lock': Permission denied
# fatal: Not a git repository (or any parent up to mount point /build)










# fc='full_chip.3'
fc=`/bin/ls -td full* | head -1`; echo "fc='$fc'"

for f in $fc/logs.00/*; do echo $f:; sed 's/^/  /' $f ; echo ""; done
# full_chip.3/logs.00/make11-hold.log:
#   PASS make cadence-innovus-postroute_hold
# 
# full_chip.3/logs.00/make12-lvs.log:
#   FAIL make mentor-calibre-lvs
#   **ERROR: Failed in LVS

flog=`/bin/ls -td *HIST/* | head -1`; echo "flog='$flog'"
less $flog


##############################################################################

# ???
# Sequence:
#    ssh buildkite-agent@r7arm-aha
#    cd /build/CI; $garnet/bin/mflowgen/buildchip.sh |& tee buildchip.log






#unit tests - r7arm
if [ ] ; then
# alias bc=~/buildchip.sh
alias bc=$garnet/mflowgen/bin/bigtest.sh
# mkdir /tmp/deleteme; cd /tmp/deleteme

test -e /tmp/deleteme.buildchip.CI || mkdir -p /tmp/deleteme.buildchip.CI
cd /tmp/deleteme.buildchip.CI

# bc --new /tmp/deleteme
# c; bc --new foo |& tee bc.log | less
c; bc |& tee bc.log



ls /tmp/deleteme.buildchip.CI/full_chip.HIST
#     full_chip.0    full_chip.109  full_chip.15  full_chip.26
#     full_chip.1    full_chip.11   full_chip.16  full_chip.27
#     ...

fi

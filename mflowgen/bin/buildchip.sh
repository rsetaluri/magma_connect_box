#!/bin/bash

# Auto-generated by '/home/steveri/tmpdir/pipegen.sh'
# Thu Oct  1 12:34:20 PDT 2020
# Sort of.

gdefault=/sim/steveri/soc/components/cgra/garnet
mdefault=/sim/buildkite-agent/mflowgen

########################################################################
cmd=$0
cmd=buildchip.sh

function Usage {
    echo "Usage: $cmd [ --new <dir> | --restart <dir> ]"
}

function Help {
    cat <<EOF

This script builds our entire chip.
It is recommended to have at least 100G of space available.

Usage: $cmd [ --new <dir> | --restart <dir> ]

Optional environment:
    GARNET_HOME,   default=\$gdefault
    MFLOWGEN_HOME, default=\$mdefault

Options:
    (none)          basically does "make chip" in the current directory

    '--make_only'   skip all the setup and just do the make commands

    '--new' <dir>   creates a new directory '<dir>/build.<n>' and builds the chip there.

    '--retry' <dir> attempts to restart an existing failed build <dir>
                    (same as 'cd <dir>; $cmd')

History:
   On arm machine, build history is maintained in /build/CI/build.HIST
   On vde machine, build history is maintained in /proj/forward/CI/build.HIST
    
Examples:
   $cmd --new   /build/CI          ; # Creates new directory "/build/build.<n>"
   $cmd --new   /proj/forward/CI          ; # Creates new directory "build.<n>"
   $cmd --retry /proj/forward/CI/build.14 ; # Builds in existing directory
   $cmd |& tee buildchip.log              ; # Basically does "make lvs" in cur dir

(Aliases for --restart include --retry, --continue, --cont ...)

EOF
}

# Sequence:
#    ssh buildkite-agent@r7arm-aha
#    cd /build/CI; $garnet/bin/mflowgen/buildchip.sh |& tee buildchip.log

[ "$GARNET_HOME"   ] || GARNET_HOME=$gdefault
[ "$MFLOWGEN_HOME" ] || MFLOWGEN_HOME=$mdefault

########################################################################
# command-line args
ACTION=new
if [ "$1" == "" ]; then
    Help; exit 13
fi
case "$1" in
    -v|--verbose) VERBOSE=true;  shift ;;
    -q|--quiet)   VERBOSE=false; shift ;;
    -h|--help)    Help; exit ;;

    --new)   ACTION=new; shift; build_dir=$1 ;;
    --re*)   ACTION=old; shift; build_dir=$1 ;;
    --cont*) ACTION=old; shift; build_dir=$1 ;;

    --make*) ACTION=make_only; shift ;;

    *) echo "**ERROR: Unrecognized command-line arg '$1'"; Usage; exit 13; ;;
esac
# echo ACTION=$ACTION

########################################################################
# A special tool that will help us later...
function get_next_name {
    # Given existing files /a/b/c.{0,1,14,22}, return next logical name "/a/b/c.23"
    root=$1
    n=`\ls -d $root.* |& \egrep "^$root.[0-9]*" | sed "s|^$root.||" | sort -n | tail -1`
    if ! [ "$n" ]; then echo $root.0; else echo $root.$((n+1)); fi
}

########################################################################
if [ "$ACTION" == "new" ]; then
    if [ "$build_dir" == "" ]; then 
        echo "**ERROR: No build dir on command line"; Usage; exit 13;
    fi

    ########################################################################
    # Find a number, build a log
    # 
    # Maybe build numbers are coordinated by a world-writable directory
    # full of build logs e.g. /build/buildchip_logs/{build.0,build.1,build.2...}

    logdir=/proj/forward/CI/build.HIST ;  # For VDE
    [ `hostname` == "r7arm-aha" ] && logdir=/build/CI/build.HIST ; # for ARM
    if ! (test -d $logdir && test -w $logdir); then
        echo "**ERROR: logdir $logdir not found or not writeable"; exit 13
    fi

    build=`cd $logdir; get_next_name build` ; # e.g. 'build.14'
    log=$logdir/$build;                       # e.g. '/build/build.HIST/build.14'
    build_dir=$build_dir/$build    

    echo `date` $build | tee $log

    echo "Initiating new build in dir '$build_dir'" | tee -a $log
    mkdir -p $build_dir |& tee -a $log
    echo cd $build_dir |& tee -a $log
    cd $build_dir; 
    echo "Log file = '$logdir/$build'" | tee -a $log

    ########################################################################
    # Build the chip, with output to the log.
    # Set pipefail so we get the correct exit status.

    if [ `hostname` == "r7arm-aha" ]; then

        if ! [ "$USER" == "buildkite-agent" ]; then
            echo "**ERROR: you are not buildkite-agent, this will not work"
            exit 13
        fi

        # Do I want to do this?
        # FIXME if we're gonna do it, we should do it up at the top
        if [ "$GARNET_HOME" ]; then
            echo "Found existing GARNET_HOME='$GARNET_HOME'; hope that's correct...!"
        else
            function where_this_script_lives {
                s=${BASH_SOURCE[0]}
                scriptpath=$s      # E.g. "build_tarfile.sh" or "foo/bar/build_tarfile.sh"
                scriptdir=${s%/*}  # E.g. "build_tarfile.sh" or "foo/bar"
                if test "$scriptdir" == "$scriptpath"; then scriptdir="."; fi
                # scriptdir=`cd $scriptdir; pwd`
                (cd $scriptdir; pwd)
            }
            script_home=`where_this_script_lives`
            export GARNET_HOME=`cd $script_home/../..; pwd`
            echo "Setting GARNET_HOME='$GARNET_HOME'; hope that's correct...!"
        fi
        echo sourcing things
        need_space=100G

        # Setup script "source setup-buildkite.sh --dir <d>" does the following:
        #   - if unset yet, sets GARNET_HOME to wherever the setup script lives
        #   - checks <d> for sufficient disk space;
        #   - sets TMPDIR to /sim/tmp
        #   - sets python env BUT ONLY if you're running as buildkite-agent
        #   - source garnet-setup.sh for CAD paths
        #   - *finds or creates requested build directory <d>*
        #   - makes local link to mflowgen repo "/sim/buildkite-agent/mflowgen"
        #   - makes local copy of adk

        # We still need/want this, right? Not sure how it's gonnna work on VDE
        garnet=$GARNET_HOME
        echo "Sourcing 'setup-buildkite.sh'..."
        source $GARNET_HOME/mflowgen/bin/setup-buildkite.sh \
               --dir $build_dir \
               --need_space $need_space \
            || exit 13


        # Duhhhhh...is this too stoopid?
        gtmp=/sim/tmp/deleteme.garnet
        test -e $gtmp && /bin/rm -rf $gtmp
        mkdir -p $gtmp
        git clone https://github.com/StanfordAHA/garnet $gtmp
        (cd $gtmp; git checkout adad99d)
        export GARNET_HOME=$gtmp
    fi
    
    which mflowgen
    mflowgen run --design $GARNET_HOME/mflowgen/full_chip || exit 13
    set -o pipefail; exec $0 --make_only |& tee -a $log

    # Unit test:
    if [ ]; then 
        echo $0 --new /tmp/deleteme
    fi


elif  [ "$ACTION" == "old" ]; then
    cd $build_dir
    if [ "$build_dir" == "" ]; then 
        echo "**ERROR: No build dir on command line"; Usage; exit 13
    fi
fi

# echo FOO; exit


# # If no existing dir specified, build a new dir 'build.<n>'
# if [ "$1" == "--restart" ]; then
#     if [ "$2" == "" ]; then echo ERROR; exit 13; fi
#     build_dir=$2
#     echo "Building in existing dir '$build_dir'"
# else
#     # Build a new directory $CI/build.<n>
#     CI=/proj/forward/CI
#     build_dir=`get_next_name $CI/build`
#     mkdir -p $build_dir
#     echo "Building in new dir '$build_dir'"
# fi
# 
# cd $build_dir


# Logs go to to next avail directory logs00/, logs01/, logs02/ ...
# (yes this is different so what)
i=0; ii=00; while test -e logs.$ii; do ((i+=1)); ii=`printf "%02d" $i`; done
LD=logs.$ii; mkdir $LD

# For testing purposes, just echo the date or something
function make {
    printf "make %-30s >& %s\n" $1 $2
    # set +x >& /dev/null
    # echo `date`
    if [ "$1" == "mentor-calibre-lvs" ]; then
        echo FAIL make $1 >> $2
        echo "**ERROR: Failed in LVS" | tee -a $2 ; exit 13
    fi
    echo PASS make $1 >> $2
    sleep 1 ; # for sequential timestamps maybe
    # set -x
}

make rtl                             $LD/make-rtl.log          || exit 13
make tile_array                      $LD/make-tile_array.log   || exit 13
make glb_top                         $LD/make-glb_top.log      || exit 13
make global_controller               $LD/make-GLC.log          || exit 13
make dragonphy                       $LD/make-dragon.log       || exit 13
make soc-rtl                         $LD/make-soc-rtl.log      || exit 13
make synopsys-dc-synthesis           $LD/make-syn.log          || exit 13
make cadence-innovus-cts             $LD/make-cts.log          || exit 13
make cadence-innovus-place           $LD/make-place.log        || exit 13
make cadence-innovus-route           $LD/make-route.log        || exit 13
make cadence-innovus-postroute       $LD/make-postroute.log    || exit 13
make cadence-innovus-postroute_hold  $LD/make-hold.log         || exit 13
make mentor-calibre-lvs              $LD/make-lvs.log          || exit 13
make mentor-calibre-drc              $LD/make-drc.log          || exit 13


# To view logs:
# logdir=logs.01
# (for l in `ls -rt $logdir`; do echo ---; echo $l; cat $logdir/$l; done) | less
# (for l in `ls -rt $logdir`; do cat $logdir/$l; done)

exit

#unit tests
if [ ] ; then
alias bc=~/buildchip.sh
mkdir /tmp/deleteme; cd /tmp/deleteme
bc |& tee bc.log
#     make rtl                            >& logs.08/make-rtl.log
#     make tile_array                     >& logs.08/make-tile_array.log
#     make glb_top                        >& logs.08/make-glb_top.log
#     ...
#     make mentor-calibre-lvs             >& logs.08/make-lvs.log
#     **ERROR: Failed in LVS
logdir=logs.09
(for l in `ls -rt $logdir`; do cat $logdir/$l; done)

bc --new /tmp/deleteme


fi




########################################################################
# OLD




# '--retry' does this:
# 
# If <dir> exists, cd to that dir and build the chip.
# Because of how make dependences work, it should resume from wherever
# the previous build left off.




# Given CI directory CI e.g. CI=/proj/forward/CI;
# finds and builds next dir

# Does one of two things:
# - build new chip starting from scratch
# - continues an existing build starting from where prev build left off (crashed)

# Given a directory containing various file/dir names <rootname>.<n>, e.g.
# "foo.0 foo.1 ... foo.101", returns next sequential filename e.g. "foo.102"
# Examples:
#    $0 build                     => build.0
#    $0 /tmp/deleteme.10329/build => /tmp/deleteme.10329/build.103

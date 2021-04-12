#!/bin/bash

# Helper script for the process of running postroute_hold 
# with the possibility of one or more retries in case of failure
# 
# Example: prh.sh /build/prh3647 0
# 
# - Creates and runs from next dir bd="$1/try$2" e.g. "/build/prh3647/try0"
# -- if $bd exists, copies e.g. "/build/prh3647/try0" to "/build/prh3647/try0.fail1"
# 
# - links to gold dir steps
#     *-cadence-innovus-postroute
#     *-cadence-innovus-flowsetup
# 
# - Runs 'make postroute_hold' and checks for failure
# 
# - Records progress in make-prh.log file
# 
# - Designed to be called from a buildkite yml script something like:
#     env:
#       PRH : ".buildkite/bin/prh.sh /build/prh${BUILDKITE_BUILD_NUMBER}"
#     steps:
#       commands:
#       - 'set -x; i=0; $$PRH $$i || $$PRH $$i || $$PRH' $$i

# Cached design for postroute_hold inputs lives here
REF=/sim/buildkite-agent/gold
# REF=/build/gold.228

# Results will go to designated build dir e.g. /build/qrh3549/try0
DESTDIR=$1/try$2

# if DESTDIR exists, copy e.g. "/build/prh3647/try0" to "/build/prh3647/try0.fail1"
if test -e $DESTDIR; then
    echo "Found already-existing build dir '$DESTDIR'"
    echo "Assume it's a fail; look for a place to stash it"
    for i in 1 2 3 4 5 6 7 8 9; do
        nextfail=$DESTDIR.fail$i
        test -e $nextfail || break
    done
    echo "Found candidate fail dir name '$nextfail'"
    set -x; mv $DESTDIR $nextfail; set +x
fi

# Create new build dir
set -x
  mkdir -p $DESTDIR
set +x

# Replace current process image with one that tees output to log file
exec > >(tee -i $DESTDIR/make-prh.log) || exit 13

# Replace (new) current process image with one that sends stderr to stdout
exec 2>&1 || exit 13

# Set up the environment for the run
source mflowgen/bin/setup-buildkite.sh --dir $DESTDIR --need_space 1G;
mflowgen run --design $GARNET_HOME/mflowgen/full_chip;

# Build the necessary context to run postroute_hold step only
GOLD=/sim/buildkite-agent/gold/full_chip

# Want two steps
#     *-cadence-innovus-postroute
#     *-cadence-innovus-flowsetup

echo "+++ PRH TEST RIG SETUP - symlink to steps in $GOLD";
for step in cadence-innovus-postroute cadence-innovus-flowsetup; do
    echo $step
    stepnum=$(cd $REF/full_chip; make list |& egrep ": $step\$" | awk '{print $2}')
    ref_step=$REF/full_chip/$stepnum-$step
    echo Found ref step $ref_step; echo ''
    if ! test -d $ref_step; then
        echo "hm look like $ref_step don't exist after all..."
        exit 13
    fi

    make list |& egrep ": $step\$"
    stepnum=$(make list |& egrep ": $step\$" | awk '{print $2}')
    local_step=$stepnum-$step
    echo Found local step $local_step; echo ''

    echo "Ready to do: ln -s $REF/$ref_step $local_step"
    set -x; ln -s $ref_step $local_step; set +x

    ls -d $local_step/*

done


# echo did we get away with it?
echo "+++ TODO LIST"
function make-n-filter { egrep '^mkdir.*output' | sed 's/output.*//' | egrep -v ^Make ;}
make -n cadence-innovus-postroute_hold |& make-n-filter

# echo "+++ continue"



# echo "+++ PRH TEST RIG SETUP - stash-pull context from $GOLD";
# $GARNET_HOME/.buildkite/bin/prh-setup.sh $GOLD || exit 13

# # See if things are okay so far...
# echo CHECK1
# echo pwd=`pwd`
# /bin/ls -1
# echo ''


echo "--- QRC TEST RIG SETUP - swap in new main.tcl";
echo "temporarily changed setup-buildkite.sh to use mfg branch 'qrc-crash-fix'"
echo '========================================================================'
echo '========================================================================'
echo '========================================================================'
set -x
  (cd ../mflowgen; git branch) || echo nope
  cat ../mflowgen/steps/cadence-innovus-postroute_hold/scripts/main.tcl || echo nope
set +x
echo '========================================================================'
echo '========================================================================'
echo '========================================================================'



# ########################################################################
# # Build a new main.tcl
# # Until we can fix mflowgen repo, will need to fix main.tcl here.
# # Mainly changing multi-cpu from 16 back to 8.
# 
# main_tcl_new='
# setOptMode -verbose true
# 
# setOptMode -usefulSkewPostRoute true
# 
# setOptMode -holdTargetSlack  $::env(hold_target_slack)
# setOptMode -setupTargetSlack $::env(setup_target_slack)
# 
# puts "Info: Using signoff engine = $::env(signoff_engine)"
# 
# if { $::env(signoff_engine) } {
#   setExtractRCMode -engine postRoute -effortLevel signoff
# }
# 
# # SR Mar 2021 changed multiCpuUsage from 16 back to 8.
# # It seems to have helped the QRC core-dump problem
# # (twenty-ish consecutive runs with no error). Also,
# # from Innovus User Guide Product Version 19.10,
# # dated April 2019, p. 1057:
# # 
# # "Generally, performance improvement will start to diminish beyond 8 CPUs."
# 
# echo ""
# echo "--- BEGIN optDesign -postRoute -hold"
# setDistributeHost -local
# setMultiCpuUsage -localCpu 8
# 
# # Run the final postroute hold fixing
# optDesign -postRoute -outDir reports -prefix postroute_hold -hold
# '
# 
# ########################################################################
# # Write the new main.tcl
# 
# echo "$main_tcl_new" > scripts/main.tcl
# echo '=================================================================='
# echo 'cat scripts/main.tcl'
# cat scripts/main.tcl
# echo '=================================================================='

########################################################################
# Define the watcher, watches for 'slow or hanging' jobs warning
# Also see ~steveri/0notes/vto/qrc-slow-or-hanging.txt
function watch_for_hang {
    # sleep_period=1 ;  # Every second for testing
    sleep_period=750; # Check every fifteen minutes I guess
    while [ true ]; do
        tag="HANG MONITOR $(date +%H:%M)" ; # per-loop tag

        # grep -l
        #   Suppress normal output; instead print the name of each matching file.
        #   Scanning stops on the first match [for each file?].

        hunglogs=$(grep -ls 'slow or hanging' *postroute_hold/qrc*.log)
        for log_name in $hunglogs; do

            echo "$tag Found slow hanging log '$log_name'"
            echo $tag $log_name
            
            # Find innovus process id where 
            # e.g. if log_name=qrc_6717_20210326_21:19:09.log then pid=6717
            pid=$(echo $log_name | sed 's/^qrc_//' | sed 's/_.*//')
            echo "$tag process id=? $pid ?"
            echo "$tag found hung process $pid"

            # See if process exists (still)
            ps -p $pid || continue
            
            # Found a hung process; now kill it
            echo "Process $pid is (still) valid / running"
            echo ""
            echo 'List of hung processes dependent on $pid'
            echo 'ps -xo "%p %P %y %x %c" --sort ppid | grep $pid'
            ps -xo "%p %P %y %x %c" --sort ppid | grep $pid
            echo ""
            echo "$tag KILL $pid !"
            echo "kill $pid"
            kill $pid
            echo "$tag DONE"
            return
        done
        echo $tag No slow hangers yet...; sleep $sleep_period; continue
    done
}

# # Kill all background jobs (i.e. the watcher) when this script exits
# # (May not be strictly necessary...?)
# trap '
#   echo ""
#   echo "kill hung jobs"
#   sleep 1; # Wait a sec, see if they die on their own
#   [ "$(jobs -p)" ] && echo "no hung jobs to kill"
#   [ "$(jobs -p)" ] && kill $(jobs -p)
# ' EXIT

# Launch the watcher
watch_for_hang |& tee -i hang-watcher.log &

########################################################################
# DO IT MAN! Run the step.

function RUN_THE_STEP {
    # Executes mflowgen-run, which basically does 
    # - 'exit 13' prevents hang at prompt on innovus failure
    # - '||' prevents exit on error
    # - ENDSTATUS notification lets us process errors later
    # echo "--- restore-design and setup-session"; # set -o pipefail;


    # echo "--- DO MFLOWGEN-RUN"
    # echo exit 13 | ./mflowgen-run && echo ENDSTATUS=PASS || echo ENDSTATUS=FAIL

    echo "--- MAKE CADENCE-INNOVUS-POSTROUTE_HOLD"

    echo exit 13 | make cadence-innovus-postroute_hold \
        && echo ENDSTATUS=PASS || echo ENDSTATUS=FAIL

}
RUN_THE_STEP |& tee -i make-prh.log

########################################################################
echo "+++ CLEAN UP, delete 14G of context"

# Clean up
echo ''
echo "--- save disk space, delete output design (?)"
set -x
if test -d checkpoints; then
    ls -lR checkpoints/
    /bin/rm -rf checkpoints/*
    touch checkpoints/'deleted to save space'
fi

echo ''
echo "--- save disk space, delete copied gold steps"
prhname=$(/bin/ls -d *postroute_hold); echo $prhname
for step in $(/bin/ls -d [0-9]*); do
    if [ "$step" == "$prhname" ]; then
        echo "SKIP '$prhname' (obviously)"; continue
    else
        echo "/bin/rm -rf $step"
        /bin/rm -rf $step
    fi
done
echo ''

########################################################################
echo "+++ QCHECK: PASS or FAIL?"

# Hung job
echo ''
echo 'Check for hung job'
pid=$(grep 'found hung process' hang-watcher.log | awk '{print $NF}')
if [ "$pid" ]; then
    echo "+++ QCHECK PROBLEM: HUNG JOB $pid"
    FOUND_ERROR=HUNG
    exit 13
fi

# Other QRC problems
echo ''
echo 'Check for QRC error(s)'
echo "egrep '^ Error messages'" qrc*.log
egrep '^ Error messages' qrc*.log
n_errors=$(egrep '^ Error messages' mflowgen-run.log | awk '{print $NF}')
for i in $n_errors; do 
    if [ "$i" -gt 0 ]; then 
        echo ''
        echo "+++ QCHECK PROBLEM: QRC ERRORS"
        echo "FAILED n_errors, flagging QRC for retry"
        FOUND_ERROR=QRC
        exit 13
    fi
done

# Unknown error
echo ''
echo 'Check for other / unknown error(s)'
if grep ENDSTATUS=FAIL mflowgen-run.log; then
    echo "+++ QCHECK: FAILED mflowgen with unknown cause, giving up now"
    FOUND_ERROR=FAIL
    exit 13
fi

# Huh, must have passed.
echo "+++ QCHECK: NO ERRORS FOUND, HOORAY!"
echo "+++ PASSED mflowgen first attempt"
echo "Hey looks like we got away with it"

# (exit 0)

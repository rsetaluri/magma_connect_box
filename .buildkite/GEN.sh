#!/bin/bash

# Exit on error in any stage of any pipeline
set -eo pipefail

VERBOSE=false
if   [ "$1" == "-v" ] ; then VERBOSE=true;  shift;
elif [ "$1" == "-q" ] ; then VERBOSE=false; shift;
fi

# Bad news if CACHEDIR no existee
if [ "$CACHEDIR" == "" ]; then
  echo "INFO $0 oops CACHEDIR not set"
  echo "INFO WARNING will set CACHEDIR to '.' (no cachedir)"
  CACHEDIR=.
fi
  echo "INFO WARNING CACHEDIR='$CACHEDIR'"

# little hack
LITTLE=''
if [ "$1" == "--LITTLE" ] ; then LITTLE="$1"; shift; fi


##############################################################################
echo "--- GENERATE GARNET VERILOG, PUT IT IN CORRECT FOLDER FOR SYNTH/PNR"

set -x
cd tapeout_16
  test/generate.sh -v $LITTLE
cd ..

pwd; ls -ld genesis_verif
cp garnet.v genesis_verif/garnet.sv

# Move genesis_verif to its final home in the cache dir
if [ ! "$CACHEDIR" == "." ]; then
    test -d $CACHEDIR/genesis_verif && /bin/rm -rf $CACHEDIR/genesis_verif
    cp -r genesis_verif/ $CACHEDIR/genesis_verif || exit 13
    ls -ld $CACHEDIR/genesis_verif

    # Same for mem*.txt
    pwd; ls -l mem_cfg.txt mem_synth.txt
    cp mem_cfg.txt mem_synth.txt $CACHEDIR/
fi

# Summary
set +x
echo "+++ SUMMARY"
echo "Built genesis_verif/, mem_cfg.txt, mem_synth.txt"
echo "Moved garnet.v => genesis_verif/garnet.sv"
echo "Moved genesis_verif/, mem_*.txt to cache directory $CACHEDIR"
date
ls -ld $CACHEDIR/{genesis_verif,mem_*.txt}

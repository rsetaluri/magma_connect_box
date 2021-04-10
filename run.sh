#!/bin/bash

export APP=$1
export DSE_PE=$2
export HEIGHT=8
export WIDTH=8
export CLK=1c1

home=$PWD

cd mflowgen/Tile_PE
build_dir=build_${DSE_PE}_${APP}_${CLK}
mkdir ${build_dir}
mflowgen run --design ../
make post-synth-power
cd ../Tile_MemCore
mkdir ${build_dir}
mflowgen run --design ../
mflowgen stash link --path /sim/kzf/pe-dse/stash/2021-0409-mflowgen-stash-1b421f
mflowgen stash pull --hash 2aec61
make post-synth-power

cd ${home}
results_dir=../micro-2021/pe-dse-power/micro2021/results/${DSE_PE}/${APP}/${CLK}
for t in Tile_PE Tile_MemCore; do
    mkdir -p ${results_dir}/${t}
    cp mflowgen/${t}/${build_dir}/*-post-synth-power/outputs/reports/* ${results_dir}/${t}
done

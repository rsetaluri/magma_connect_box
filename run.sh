#!/bin/bash

export APP=$1
export DSE_PE=$2
export HEIGHT=$3
export WIDTH=$4
export CLK=1c1

home=$PWD/mflowgen

cd mflowgen
build_dir=build_${DSE_PE}_${APP}_${CLK}
mkdir ${build_dir}
cd ${build_dir}
git clone --branch pe-dse-power https://github.com/StanfordAHA/garnet.git

mkdir Tile_PE
cd Tile_PE
mflowgen run --design ../garnet/mflowgen/Tile_PE
make post-synth-power

cd ../
mkdir Tile_MemCore
cd Tile_MemCore
mflowgen run --design ../garnet/mflowgen/Tile_MemCore
mflowgen stash link --path /sim/kzf/pe-dse/stash/2021-0409-mflowgen-stash-1b421f
mflowgen stash pull --hash 2aec61
make post-synth-power

cd ${home}
results_dir=../micro-2021/pe-dse-power/micro2021/results/${DSE_PE}/${APP}/${CLK}
for t in Tile_PE Tile_MemCore; do
    mkdir -p ${results_dir}/${t}
    cp mflowgen/${build_dir}/garnet/${t}/*-post-synth-power/outputs/reports/* ${results_dir}/${t}
done

#!/bin/bash

export APP=$1
export DSE_PE=${APP}_$2
export CLK=1c1

home=$PWD

cd mflowgen
build_dir=build_${2}_${APP}_${CLK}
mkdir ${build_dir}
cd ${build_dir}

mkdir Tile_PE
cd Tile_PE
mflowgen run --design ../../Tile_PE
make post-synth-power

cd ../
mkdir Tile_MemCore
cd Tile_MemCore
mflowgen run --design ../../Tile_MemCore
mflowgen stash link --path /sim/kzf/pe-dse/stash/2021-0409-mflowgen-stash-1b421f
mflowgen stash pull --hash cb6216
cp -r ../Tile_PE/*-application .
make -t 0
make post-synth-power

cd ${home}
results_dir=../micro-2021/pe-dse-power/micro2021/results/${2}/${APP}/${CLK}
mkdir -p ${results_dir}
cp mflowgen/${build_dir}/Tile_PE/*-application/outputs/*.list ${results_dir}
for t in Tile_PE Tile_MemCore; do
    mkdir -p ${results_dir}/${t}
    cp mflowgen/${build_dir}/${t}/*-post-synth-power/outputs/reports/* ${results_dir}/${t}
done

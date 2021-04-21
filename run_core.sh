#!/bin/bash 

export APP=$1
export DSE_PE=${APP}_$2_dg
export CLK=0c7

home=$PWD

cd mflowgen
build_dir=build_core_${2}_${APP}_${CLK}
mkdir ${build_dir}
cd ${build_dir}

mflowgen run --design ../../DC_PE_Core
make post-synth-power

cd ${home}
results_dir=../micro-2021/pe-dse-power/micro2021/results/core/${2}/${APP}/${CLK}
mkdir -p ${results_dir}
cp mflowgen/${build_dir}/*-application/outputs/*.list ${results_dir}
cp mflowgen/${build_dir}/*-synopsys-dc-synthesis/reports/*.mapped.area.rpt ${results_dir}
mkdir -p ${results_dir}/reports
cp mflowgen/${build_dir}/*-post-synth-power/outputs/reports/* ${results_dir}/reports

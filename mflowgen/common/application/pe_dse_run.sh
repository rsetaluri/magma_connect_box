#!/bin/bash

# Build up the flags we want to pass to python garnet.v
flags="--width $app_array_width --height $app_array_height --pipeline_config_interval $pipeline_config_interval -v --interconnect-only --no-pond"
map_flags="--width $app_array_width --height $app_array_height --pipeline_config_interval $pipeline_config_interval --interconnect-only --no-pond"

if [ ${PWR_AWARE} = "False" ]; then
  flags="$flags --no-pd"
  map_flags="$map_flags --no-pd"
fi

if [ $dse_pe !=  "lassen" ]; then
    flags="$flags --pe $dse_pe/PE.json"
fi

home=$PWD

cd $GARNET_HOME
#python garnet.py ${flags}
python tbg.py ${dse_pe}/garnet.v ${dse_pe}/garnet_stub.v ${dse_pe}/${app_to_run}.bs.json
cp ${home}/Interconnect_cmd.tcl $GARNET_HOME/${dse_pe}/temp/garnet/
cd $GARNET_HOME/${dse_pe}/temp/garnet
xrun -top Interconnect_tb -timescale 1ns/1ns -input Interconnect_cmd.tcl $GARNET_HOME/${dse_pe}/temp/garnet/Interconnect_tb.sv Interconnect.sv CW_fp_add.v CW_fp_mult.v Interconnect.sv AN2D0BWP16P90.sv AO22D0BWP16P90.sv Interconnect_tb.sv -access r -notimingchecks -neverwarn

cd ${home}
mv $GARNET_HOME/${dse_pe}/temp/garnet/waves.shm outputs/waves.shm

grep '#m' $GARNET_HOME/${dse_pe}/design.place | awk '{printf "%s,%02X,%02X\n",$1,$2,$3}' > outputs/tiles_Tile_MemCore.list
grep '#p' $GARNET_HOME/${dse_pe}/design.place | awk '{printf "%s,%02X,%02X\n",$1,$2,$3}' > outputs/tiles_Tile_PE.list

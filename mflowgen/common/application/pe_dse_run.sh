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

cd $GARNET_HOME
python garnet.py ${flags}
python tbg.py garnet.v garnet_stub.v ${dse_pe}/${app_to_run}.bs.json

cd -
cp $GARNET_HOME/temp/garnet/waveforms.vcd outputs/run.vcd

grep '#m' $GARNET_HOME/${dse_pe}/design.place | awk '{printf "%s,%02X,%02X\n",$1,$2,$3}' > outputs/tiles_Tile_MemCore.list
grep '#p' $GARNET_HOME/${dse_pe}/design.place | awk '{printf "%s,%02X,%02X\n",$1,$2,$3}' > outputs/tiles_Tile_PE.list

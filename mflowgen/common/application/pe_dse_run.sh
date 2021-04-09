#!/bin/bash

# Build up the flags we want to pass to python garnet.v
flags="--width $array_width --height $array_height --pipeline_config_interval $pipeline_config_interval -v --interconnect-only"
map_flags="--width $array_width --height $array_height --pipeline_config_interval $pipeline_config_interval --interconnect-only"

if [ ${PWR_AWARE} = "False" ]; then
  flags="$flags --no-pd"
  map_flags="$map_flags --no-pd"
fi

cd $GARNET_HOME
python garnet.py ${flags}
python tbg.py garnet.v garnet_stub.v pointwise/pointwise.bs.json

cp $GARNET_HOME/temp/garnet/waveforms.vcd ../outputs/run.vcd

grep '#m' ../design.place | awk '{printf "%s,%02X,%02X\n",$1,$2,$3}' > ../outputs/tiles_Tile_MemCore.list
grep '#p' ../design.place | awk '{printf "%s,%02X,%02X\n",$1,$2,$3}' > ../outputs/tiles_Tile_PE.list
# Kill the container
docker kill $container_name
echo "killed docker container $container_name"
cd $current_dir

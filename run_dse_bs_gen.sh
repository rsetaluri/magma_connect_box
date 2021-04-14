python garnet.py --no-pd --no-pond --interconnect-only --width $1 --height $1 --input-app $2_$3/$2_to_metamapper.json --input-file $2_$3/input.raw --output-file $2_$3/$2.bs --gold-file $2_$3/gold.raw --pe $2_$3/PE.json $4
cp garnet.v $2_$3/
cp garnet_stub.v $2_$3/
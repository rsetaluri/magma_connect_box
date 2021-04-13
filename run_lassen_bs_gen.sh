python garnet.py --no-pd --no-pond --interconnect-only --width $1 --height $1 --input-app $2_lassen/$2_to_metamapper.json --input-file $2_lassen/input.raw --output-file $2_lassen/$2.bs --gold-file $2_lassen/gold.raw $3
cp garnet.v $2_lassen/
cp garnet_stub.v $2_lassen/
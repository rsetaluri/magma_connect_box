python garnet.py --no-pd --no-pond --interconnect-only --width $1 --height $1 --input-app $2_dse/$2_to_metamapper.json --input-file $2_dse/input.raw --output-file $2_dse/$2.bs --gold-file $2_dse/gold.raw --pe $2_dse/PE.json $3
cp garnet.v harris_dse/
cp garnet_stub.v harris_dse/
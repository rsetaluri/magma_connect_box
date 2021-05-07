python garnet.py --no-pd --no-pond --interconnect-only --width $1 --height $1 --input-app $2_lassen_dg/$2_to_metamapper.json --input-file $2_lassen_dg/input.raw --output-file $2_lassen_dg/$2.bs --gold-file $2_lassen_dg/gold.raw $3
if [ -z $3 ]; then
    cp garnet.v $2_lassen_dg/
    cp garnet_stub.v $2_lassen_dg/
fi
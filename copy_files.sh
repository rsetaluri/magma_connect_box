cp ../h2hbuild/Halide-to-Hardware/apps/hardware_benchmarks/apps/$1/bin/input.raw $1_$2/input.raw
cp ../h2hbuild/Halide-to-Hardware/apps/hardware_benchmarks/apps/$1/bin/output_cpu.raw $1_$2/gold.raw
cp ../DSEGraphAnalysis/outputs/PE.json ./$1_$2/
cp ../MetaMapper/libs/pe_header.json ./$1_$2/
cp ../h2hbuild/clockwork/dse_flow/output/$1/$1_to_metamapper.json ./$1_$2/
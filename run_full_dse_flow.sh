declare -A arr
arr['gaussian']='8'
arr['harris']='16'
arr['laplacian_pyramid']='24'
arr['camera_pipeline']='24'

for app in gaussian harris laplacian_pyramid camera_pipeline
do
    echo ${app}
    echo ${arr["$app"]}
done

# cd ../DSEGraphAnalysis
# python dse_graph_analysis.py -f examples/gaussian_compute.json -f examples/harris_compute.json -f examples/camera_pipeline_compute.json -f examples/laplacian_pyramid_compute.json
# for app in gaussian harris laplacian_pyramid camera_pipeline
# do
#     cd ../MetaMapper
#     python scripts/map_dse.py ${app}_compute
#     cd ../h2hbuild/clockwork
#     bash metamapper_copy_and_run.sh ${app} IP_0
#     cd ../../garnet 
#     mkdir ${app}_IP_0
#     ./copy_files.sh ${app} IP_0
#     ./run_dse_bs_gen.sh ${arr["$app"]} ${app} IP_0 -v
# done

cd ../DSEGraphAnalysis
python dse_graph_analysis.py -f examples/gaussian_compute.json 0 -f examples/harris_compute.json 0 -f examples/camera_pipeline_compute.json 0 -f examples/laplacian_pyramid_compute.json 0
for app in gaussian harris laplacian_pyramid camera_pipeline
do
    cd ../MetaMapper
    python scripts/map_dse.py ${app}_compute
    cd ../h2hbuild/clockwork
    bash metamapper_copy_and_run.sh ${app} IP_1
    cd ../../garnet 
    mkdir ${app}_IP_1
    ./copy_files.sh ${app} IP_1
    ./run_dse_bs_gen.sh ${arr["$app"]} ${app} IP_1 -v
done

cd ../DSEGraphAnalysis
python dse_graph_analysis.py -f examples/gaussian_compute.json 0 1 -f examples/camera_pipeline_compute.json 0 1 -f examples/harris_compute.json 0 1 -f examples/laplacian_pyramid_compute.json 0 1
for app in gaussian harris laplacian_pyramid camera_pipeline
do
    cd ../MetaMapper
    python scripts/map_dse.py ${app}_compute
    cd ../h2hbuild/clockwork
    bash metamapper_copy_and_run.sh ${app} IP_2
    cd ../../garnet 
    mkdir ${app}_IP_2
    ./copy_files.sh ${app} IP_2
    ./run_dse_bs_gen.sh ${arr["$app"]} ${app} IP_2 -v
done

cd ../DSEGraphAnalysis
python dse_graph_analysis.py -f examples/gaussian_compute.json 0 -f examples/camera_pipeline_compute.json 0 1 12 -f examples/harris_compute.json 0 -f examples/laplacian_pyramid_compute.json 0
for app in gaussian harris laplacian_pyramid camera_pipeline
do
    cd ../MetaMapper
    python scripts/map_dse.py ${app}_compute
    cd ../h2hbuild/clockwork
    bash metamapper_copy_and_run.sh ${app} IP_3
    cd ../../garnet 
    mkdir ${app}_IP_3
    ./copy_files.sh ${app} IP_3
    ./run_dse_bs_gen.sh ${arr["$app"]} ${app} IP_3 -v
done


cd ../DSEGraphAnalysis
python dse_graph_analysis.py -f examples/gaussian_compute.json 0 1 -f examples/camera_pipeline_compute.json 0 -f examples/harris_compute.json 0 -f examples/laplacian_pyramid_compute.json 0
for app in gaussian harris laplacian_pyramid camera_pipeline
do
    cd ../MetaMapper
    python scripts/map_dse.py ${app}_compute
    cd ../h2hbuild/clockwork
    bash metamapper_copy_and_run.sh ${app} IP_4
    cd ../../garnet 
    mkdir ${app}_IP_4
    ./copy_files.sh ${app} IP_4
    ./run_dse_bs_gen.sh ${arr["$app"]} ${app} IP_4 -v
done

cd ../DSEGraphAnalysis
python dse_graph_analysis.py -f examples/gaussian_compute.json 0 -f examples/camera_pipeline_compute.json 0 -f examples/harris_compute.json 0 1 2 -f examples/laplacian_pyramid_compute.json 0
for app in gaussian harris laplacian_pyramid camera_pipeline
do
    cd ../MetaMapper
    python scripts/map_dse.py ${app}_compute
    cd ../h2hbuild/clockwork
    bash metamapper_copy_and_run.sh ${app} IP_5
    cd ../../garnet 
    mkdir ${app}_IP_5
    ./copy_files.sh ${app} IP_5
    ./run_dse_bs_gen.sh ${arr["$app"]} ${app} IP_5 -v
done

cd ../DSEGraphAnalysis
python dse_graph_analysis.py -f examples/gaussian_compute.json 0 -f examples/camera_pipeline_compute.json 0 -f examples/harris_compute.json 0 -f examples/laplacian_pyramid_compute.json 0 1 2
for app in gaussian harris laplacian_pyramid camera_pipeline
do
    cd ../MetaMapper
    python scripts/map_dse.py ${app}_compute
    cd ../h2hbuild/clockwork
    bash metamapper_copy_and_run.sh ${app} IP_6
    cd ../../garnet 
    mkdir ${app}_IP_6
    ./copy_files.sh ${app} IP_6
    ./run_dse_bs_gen.sh ${arr["$app"]} ${app} IP_6 -v
done



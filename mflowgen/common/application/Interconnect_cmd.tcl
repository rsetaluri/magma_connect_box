database -shm -default waves
probe -shm Interconnect_tb -depth all -all
run 1000000ns
assertion -summary -final
quit

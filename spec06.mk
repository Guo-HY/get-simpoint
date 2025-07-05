
SPEC_HOME = /home/ghy/loongson/benchmark/spec2006/cpu2006v99

# spec06
# path to benchspec/CPU2006
spec06.bench_dir = $(SPEC_HOME)/benchspec/CPU2006
# run name (directory in benchspec/CPU2006/*/run)
spec06.run = run_base_test_new_abi.0000

spec06.list += 410.bwaves
spec06.list += 416.gamess
spec06.list += 433.milc
spec06.list += 434.zeusmp
spec06.list += 435.gromacs
spec06.list += 436.cactusADM
spec06.list += 437.leslie3d
spec06.list += 444.namd
spec06.list += 447.dealII
spec06.list += 450.soplex
spec06.list += 453.povray
spec06.list += 454.calculix
spec06.list += 459.GemsFDTD
spec06.list += 465.tonto
spec06.list += 470.lbm
spec06.list += 481.wrf
spec06.list += 482.sphinx3

spec06.list += 400.perlbench
spec06.list += 401.bzip2
spec06.list += 403.gcc
spec06.list += 429.mcf
spec06.list += 445.gobmk
spec06.list += 456.hmmer
spec06.list += 458.sjeng
spec06.list += 462.libquantum
spec06.list += 464.h264ref
spec06.list += 471.omnetpp
spec06.list += 473.astar
spec06.list += 483.xalancbmk
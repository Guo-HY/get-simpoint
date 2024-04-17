.DEFAULT_GOAL := help
# config #####################################################

PWD = $(shell pwd)

# compile tool chain
TOOLCHAIN_PATH = $(LA64TC_HOME)
TOOLCHAIN_ARCH = loongarch64-linux-gnu
CROSS_COMPILE = $(TOOLCHAIN_PATH)/bin/$(TOOLCHAIN_ARCH)-

# spec06
# path to benchspec/CPU2006
spec06.bench_dir = $(SPEC)/benchspec/CPU2006
# run name (directory in benchspec/CPU2006/*/run)
spec06.run = run_base_test_none.0000 # run_base_ref_none.0000

# spec06 benchmarks
# spec06.list += 410.bwaves
# spec06.list += 416.gamess
# spec06.list += 433.milc
# spec06.list += 434.zeusmp
# spec06.list += 435.gromacs
# spec06.list += 436.cactusADM
# spec06.list += 437.leslie3d
# spec06.list += 444.namd
# spec06.list += 447.dealII
# spec06.list += 450.soplex
# spec06.list += 453.povray
# spec06.list += 454.calculix
# spec06.list += 459.GemsFDTD
# spec06.list += 465.tonto
# spec06.list += 470.lbm
# spec06.list += 481.wrf
# spec06.list += 482.sphinx3

# spec06.list += 400.perlbench
spec06.list += 401.bzip2
# spec06.list += 403.gcc
# spec06.list += 429.mcf
# spec06.list += 445.gobmk
# spec06.list += 456.hmmer
# spec06.list += 458.sjeng
# spec06.list += 462.libquantum
# spec06.list += 464.h264ref
# spec06.list += 471.omnetpp
# spec06.list += 473.astar
# spec06.list += 483.xalancbmk

# ramfs
BASE_RAMFS_OUTDIR = $(PWD)/output_files/base_dir
RAMFS_OUTDIR = $(PWD)/output_files/ramfs
# ld.so path in the ramfs
LD_SO = /lib64/ld.so.1
# ramfs options
SUITE = spec06
RATE = 1

BENCH_LIST = $($(SUITE).list)
RAMFS_LIST = $(foreach x,$(BENCH_LIST),\
			 $(patsubst $(RAMFS_OUTDIR)/%.cpio.gz,%,\
			 $(wildcard $(RAMFS_OUTDIR)/$(x)*.cpio.gz)))

# qemu
QEMU=$(PWD)/projects/qemu/build/qemu-system-loongarch64
# for qemu run
SM_INTERVAL=1000000
QEMU_FLAGS = -M loongson320 -icount shift=0,sleep=off -m 4G -nographic -monitor none

# linux
LINUX_SRCDIR=$(PWD)/projects/linux-4.19-loongson
LINUX_OUTDIR = $(PWD)/output_files/linux
# for linux-4.19-loongson build
ARCH=loongarch
LINUX_CFG=ghy_defconfig
LINUX_CFG_PATH=projects/linux-4.19-loongson/arch/loongarch/configs/$(LINUX_CFG)
LINUX_LIST = $(patsubst %,%.vmlinux,$(RAMFS_LIST))

# simpoint
SIMPOINT=$(PWD)/projects/SimPoint.3.2/bin/simpoint
SIMPOINT_OUTDIR = $(PWD)/output_files/simpoint
# for simpoint run
SIMPOINT_FLAGS = -maxK 30 -numInitSeeds 2 -iters 1000
SIMPOINT_FLAGS += -loadFVFile ./bbv.txt 
SIMPOINT_FLAGS += -saveSimpoints simpoints
SIMPOINT_FLAGS += -saveSimpointWeights weights

##############################################################

BASE_RAMFS_TARGET = $(BASE_RAMFS_OUTDIR)/.gen
base_ramfs: $(BASE_RAMFS_TARGET)

base_ramfs_clean:
	rm -rf $(BASE_RAMFS_OUTDIR)

INIT_SRCS = init.c

$(BASE_RAMFS_OUTDIR)/.gen: $(INIT_SRCS)

	mkdir -p $(BASE_RAMFS_OUTDIR)
	$(CROSS_COMPILE)gcc -static -o $(BASE_RAMFS_OUTDIR)/init $(INIT_SRCS)
	cp -a $(TOOLCHAIN_PATH)/sysroot/* $(BASE_RAMFS_OUTDIR)/

	touch $@

ramfs: $(patsubst %,%.ramfs,$(BENCH_LIST))

%.ramfs: $(BASE_RAMFS_TARGET)
	mkdir -p $(RAMFS_OUTDIR)
	./scripts/gen_spec_ramfs.py $($(SUITE).bench_dir)/$*/run/$($(SUITE).run) $* $(RATE) $(BASE_RAMFS_OUTDIR) $(RAMFS_OUTDIR) $(LD_SO) >$(RAMFS_OUTDIR)/$*.log 2>&1
	echo "Generated $*"

ramfs_clean:
	rm -rf $(RAMFS_OUTDIR)


linux: $(patsubst %,%.vmlinux,$(RAMFS_LIST))
	
%.vmlinux:
	echo "Generated $*.vmlinux"
	mkdir -p $(LINUX_OUTDIR)
	sed -i 's,CONFIG_INITRAMFS_SOURCE=.*,CONFIG_INITRAMFS_SOURCE="$(RAMFS_OUTDIR)/$*.cpio.gz",g' $(LINUX_CFG_PATH)
	make -C $(LINUX_SRCDIR) $(LINUX_CFG)
	make -C $(LINUX_SRCDIR) vmlinux -j 4
	cp $(LINUX_SRCDIR)/vmlinux $(LINUX_OUTDIR)/$*.vmlinux

linux_clean:
	rm -rf $(LINUX_OUTDIR)


ckpt: $(patsubst %,%.ckpt,$(RAMFS_LIST))

%.ckpt:
	echo "Generated $* simpoint checkpoint"
	mkdir -p $(SIMPOINT_OUTDIR)/$*
	echo "Generated bbv.txt"
# Must be on one line !!!
	export SHORTCUT_CONFIG_FILE=1 && cd $(SIMPOINT_OUTDIR)/$* && $(QEMU) $(QEMU_FLAGS) -kernel $(LINUX_OUTDIR)/$*.vmlinux
	
	echo "Generated simpoints and weights"
	cd $(SIMPOINT_OUTDIR)/$* && $(SIMPOINT) $(SIMPOINT_FLAGS)

	echo "Generated checkpoint"
	export SHORTCUT_CONFIG_FILE=2 && cd $(SIMPOINT_OUTDIR)/$* && $(QEMU) $(QEMU_FLAGS) -kernel $(LINUX_OUTDIR)/$*.vmlinux

ckpt_clean:
	rm -rf $(SIMPOINT_OUTDIR)

clean:
	rm -rf output_files

help:
	@echo "step 1: make ramfs # generate ramfs use benchmark"
	@echo "step 2: make linux # generate vmlinux use ramfs"
	@echo "step 3: make ckpt  # generate simpoint checkpoint use vmlinux"

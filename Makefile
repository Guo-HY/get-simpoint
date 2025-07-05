.DEFAULT_GOAL := help
# config #####################################################

# 用来编译内核和ramfs的init.c的编译器
COMPILER_HOME = /home/ghy/loongson/la64-toolchain/x86_64-cross-tools-loongarch64-binutils_2.44-gcc_15.1.0-glibc_2.41
LA_EMU_HOME=/home/ghy/loongson/la_emu_internal
LINUX_HOME=/home/ghy/loongson/linux/linux

PWD = $(shell pwd)

# compile tool chain
TOOLCHAIN_ARCH = loongarch64-unknown-linux-gnu
CROSS_COMPILE = $(COMPILER_HOME)/bin/$(TOOLCHAIN_ARCH)-

# ramfs
BASE_RAMFS_OUTDIR = $(PWD)/output_files/base_dir
RAMFS_OUTDIR = $(PWD)/output_files/ramfs
# ld.so path in the ramfs
LD_SO = # /lib64/ld.so.1
# ramfs options
# spec06 or spec17r
SUITE = spec06
RATE = 1

include $(SUITE).mk

BENCH_LIST = $($(SUITE).list)
RAMFS_LIST = $(foreach x,$(BENCH_LIST),\
			 $(patsubst $(RAMFS_OUTDIR)/%.cpio.gz,%,\
			 $(wildcard $(RAMFS_OUTDIR)/$(x)*.cpio.gz)))

# laemu
LA_EMU=$(LA_EMU_HOME)/build/la_emu_kernel
LIBBBLK=$(LA_EMU_HOME)/plugins/libbblk.so
LIBBBV=$(LA_EMU_HOME)/plugins/libbbv.so
LIBBBVNAIVE=$(LA_EMU_HOME)/plugins/libbbv_naive.so
LIBSIMPOINT=$(LA_EMU_HOME)/plugins/libsimpoint.so

# linux
LINUX_OUTDIR = $(PWD)/output_files/linux
LINUX_CFG=tiny_defconfig
LINUX_CFG_PATH=$(LINUX_HOME)/arch/loongarch/configs/$(LINUX_CFG)
LINUX_BUILD_DIR=$(LINUX_HOME)/build_loongarch
LINUX_LIST = $(patsubst %,%.vmlinux,$(RAMFS_LIST))

# simpoint
SIMPOINT=$(PWD)/projects/SimPoint.3.2/bin/simpoint
SIMPOINT_OUTDIR = $(PWD)/output_files/simpoint
# for simpoint run
SM_INTERVAL=100000000
SIMPOINT_FLAGS = -maxK 30 -numInitSeeds 5 -iters 1000

##############################################################

BASE_RAMFS_TARGET = $(BASE_RAMFS_OUTDIR)/.gen
base_ramfs: $(BASE_RAMFS_TARGET)

base_ramfs_clean:
	rm -rf $(BASE_RAMFS_OUTDIR)

INIT_SRCS = init.c

$(BASE_RAMFS_OUTDIR)/.gen: $(INIT_SRCS)

	mkdir -p $(BASE_RAMFS_OUTDIR)
	$(CROSS_COMPILE)gcc -static -o $(BASE_RAMFS_OUTDIR)/init $(INIT_SRCS)
# cp -a $(COMPILER_HOME)/sysroot/* $(BASE_RAMFS_OUTDIR)/

	touch $@

ramfs: $(patsubst %,%.ramfs,$(BENCH_LIST))

%.ramfs: $(BASE_RAMFS_TARGET)
	mkdir -p $(RAMFS_OUTDIR)
	./scripts/gen_spec_ramfs.py $($(SUITE).bench_dir)/$*/run/$($(SUITE).run) $* $(RATE) $(BASE_RAMFS_OUTDIR) $(RAMFS_OUTDIR) $(LD_SO) >$(RAMFS_OUTDIR)/$*.log 2>&1
	echo "Generated $*"

ramfs_clean:
	rm -rf $(RAMFS_OUTDIR)


linux: $(patsubst %,%.vmlinux,$(RAMFS_LIST))
	
%.vmlinux: %.vmlinux_build
	cp $(LINUX_BUILD_DIR)/vmlinux $(LINUX_OUTDIR)/$*.vmlinux

%.vmlinux_config:
	echo "Generated $*.vmlinux"
	mkdir -p $(LINUX_OUTDIR)
	sed -i 's,CONFIG_INITRAMFS_SOURCE=.*,CONFIG_INITRAMFS_SOURCE="$(RAMFS_OUTDIR)/$*.cpio.gz",g' $(LINUX_CFG_PATH)
	make -C $(LINUX_HOME) ARCH=loongarch CROSS_COMPILE=$(CROSS_COMPILE) O=$(LINUX_BUILD_DIR) $(LINUX_CFG)

%.vmlinux_build: %.vmlinux_config
	make -C $(LINUX_HOME) ARCH=loongarch CROSS_COMPILE=$(CROSS_COMPILE) O=$(LINUX_BUILD_DIR) vmlinux -j 4

linux_clean:
	rm -rf $(LINUX_OUTDIR)


bblk: $(patsubst %,%.bblk,$(RAMFS_LIST))

%.bblk:
	mkdir -p $(SIMPOINT_OUTDIR)/$*
	echo "Generated bblk.txt"
	$(LA_EMU) -m 16 -k $(LINUX_OUTDIR)/$*.vmlinux -z -p $(LIBBBLK),bblk=$(SIMPOINT_OUTDIR)/$*/bblk.txt,ibar0x40=1

parallel_bblk:
	mkdir -p $(SIMPOINT_OUTDIR)
	python3 ./scripts/batch_bblk.py $(LA_EMU) $(LINUX_OUTDIR) $(LIBBBLK) $(SIMPOINT_OUTDIR)

bbv: $(patsubst %,%.bbv,$(RAMFS_LIST))

%.bbv:
	echo "Generated bbv.txt,interval=$(SM_INTERVAL)"
	$(LA_EMU) -m 16 -k $(LINUX_OUTDIR)/$*.vmlinux -z -p $(LIBBBV),bblk=$(SIMPOINT_OUTDIR)/$*/bblk.txt,bbv=$(SIMPOINT_OUTDIR)/$*/bbv.txt,interval=$(SM_INTERVAL),ibar0x40=1

bbv_naive: $(patsubst %,%.bbv_naive,$(RAMFS_LIST))

%.bbv_naive:
	mkdir -p $(SIMPOINT_OUTDIR)/$*
	echo "Generated bbv.txt,interval=$(SM_INTERVAL)"
	$(LA_EMU) -m 16 -k $(LINUX_OUTDIR)/$*.vmlinux -z -p $(LIBBBVNAIVE),bbv=$(SIMPOINT_OUTDIR)/$*/bbv.txt,interval=$(SM_INTERVAL),ibar0x40=1

parallel_bbv_naive:
	mkdir -p $(SIMPOINT_OUTDIR)
	python3 ./scripts/batch_bbv_naive.py $(LA_EMU) $(LINUX_OUTDIR) $(LIBBBVNAIVE) $(SIMPOINT_OUTDIR) $(SM_INTERVAL)

simpoint: $(patsubst %,%.simpoint,$(RAMFS_LIST))

%.simpoint:
	echo "Generated simpoints and weights"
	$(SIMPOINT) $(SIMPOINT_FLAGS) -loadFVFile $(SIMPOINT_OUTDIR)/$*/bbv.txt -saveSimpoints $(SIMPOINT_OUTDIR)/$*/simpoints -saveSimpointWeights $(SIMPOINT_OUTDIR)/$*/weights

parallel_simpoint:
	python3 ./scripts/batch_simpoint.py $(SIMPOINT) $(LINUX_OUTDIR) $(SIMPOINT_OUTDIR) $(SIMPOINT_FLAGS)

ckpt: $(patsubst %,%.ckpt,$(RAMFS_LIST))

%.ckpt:
	echo "Generated $* simpoint checkpoint"
	$(LA_EMU) -m 16 -k $(LINUX_OUTDIR)/$*.vmlinux -z -p $(LIBSIMPOINT),path=$(SIMPOINT_OUTDIR)/$*,interval=$(SM_INTERVAL),simpoints=$(SIMPOINT_OUTDIR)/$*/simpoints,weights=$(SIMPOINT_OUTDIR)/$*/weights,ibar0x40=1

parallel_ckpt:
	python3 ./scripts/batch_ckpt.py $(LA_EMU) $(LINUX_OUTDIR) $(LIBSIMPOINT) $(SIMPOINT_OUTDIR) $(SM_INTERVAL)

ckpt_json:
	python3 ./scripts/gen_ckpt_json.py --name simpoint.json --checkpoint $(SIMPOINT_OUTDIR) --sm-interval $(SM_INTERVAL)

# all_ckpt:
# 	make bblk
# 	make bbv
# 	make simpoint
# 	make ckpt

# all:
# 	make ramfs
# 	make linux
# 	make all_ckpt

ckpt_clean:
	rm -rf $(SIMPOINT_OUTDIR)

clean:
	rm -rf output_files

help:
	@echo "step 1: make ramfs 				# generate ramfs use benchmark"
	@echo "step 2: make linux 				# generate vmlinux use ramfs"
	@echo "step 3: make [parallel_]bblk			# generate basic block info use la_emu and vmlinux"
	@echo "step 4: make [parallel_]bbv			# generate basic block vector info use la_emu, vmlinux and bblk"
	@echo "step 4: make [parallel_]bbv_naive	# generate naive basic block vector info use la_emu and vmlinux"
	@echo "step 5: make [parallel_]simpoint		# generate simpoints and weights use simpoint"
	@echo "step 6: make [parallel_]ckpt			# generate simpoint checkpoint use la_emu, vmlinux, weights and simpoints"

# get-simpoint 
参考 `http://172.17.103.58/chenyuxiao/get-simpoint`, 基于 la_emu 生成 spec cpu 的 Deterministic Checkpoint Simpoint。

## 步骤
### Step1：编译 SPEC CPU
- 交叉编译器可以从[这里](https://github.com/loongson/build-tools)下载。
- 建议静态链接，免去后续打包 ramfs 时的麻烦。
- `config` 目录下有一份 spec06 和 spec17 的配置文件。

### Step2：配置 Linux
- [内核源码](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git)
- 目前部分实验平台在物理地址 0x1fe002e0 处有一个假串口，如果依赖该串口输出，则需应用 `patch/0001-loongarch-add-hvc_la-0x1fe002e0-debugcon.patch` 在linux 中添加该设备，然后将 dts 中 bootargs 中的 console 和 earlycon 都改为 hvc。
- config 文件和 dts 文件，使用 `patch` 目录下的 `0001-loongarch-add-poweroff.dts-tiny_defconfig.patch`，按需修改。注意 poweroff.dts 的 bootargs 参数中使用的默认输出是 0x1fe002e0 的假串口。
- 其它内核配置可以参考 `projects/build_mini_loongarch_kernel` 中 lxy 师兄的 patch。

### Step3：修改 Makefile
- 设置 `COMPILER_HOME` 为 LoongArch 编译器路径，`LA_EMU_HOME` 为 la_emu 的根目录，`LINUX_HOME` 为 linux 根目录。
- 设置 SULTE 为 spec06 或 spec17r。
    - 设置 `spec06.mk` 中 `SPEC_HOME` 为 speccpu2006 的根目录，`spec06.run` 为 `benchspec/CPU2006/*/run` 下要跑的目录名字（如 `run_base_ref_none.0000`），设置`spec06.list` 为所有要跑的测试点。
    - `spec17r.mk` 中类似。
- 如果 spec 二进制为静态链接，则设置 `LD_SO` 为空。如果 spec 二进制为动态链接，则需设置 `LD_SO` 为 spec 二进制运行时所需的动态链接器绝对路径，并将 Makefile 中 `$(BASE_RAMFS_OUTDIR)/.gen: $(INIT_SRCS)` 这个目标下的 `cp -a $(COMPILER_HOME)/sysroot/* $(BASE_RAMFS_OUTDIR)/` 这个注释打开，将编译器目录下的 LoongArch 架构动态库复制到 ramfs 中。需要注意编译器中动态库的具体路径在不同版本编译器中不同。
- 后续的 `LA_EMU`，`LIB*` 这几个变量需要确认其指向的二进制都存在。
- `LINUX_CFG` 和 `LINUX_CFG_PATH` 设置使用的 linux config 文件的名称和路径。注意我们默认 linux 的配置为编译 linux 时将 ramfs （以及DTS）打包在内核中，因此后续的 `%.vmlinux_config` 目标下会用 sed 命令修改 config 文件的 `CONFIG_INITRAMFS_SOURCE` 这个配置。
- `SIMPOINT` 指向 simpoint 二进制路径，需要提前进入 `projects/SimPoint3.2` 执行 make 生成这个二进制。`SM_INTERVAL` 为 simpoint 采样间隔，`SIMPOINT_FLAGS` 为其它 simpoint 设置，按需修改。

### Step4：运行
下面是生成 simpoint 采样点的具体步骤：
- 1. 用 make ramfs 命令批量生成包含所有 `BENCH_LIST` 指定的 spec 二进制的根文件系统，存放在 output_files/ramfs 路径下。
- 2. 用 make linux 命令，对每个根文件系统生成一个包含它的 vmlinux，存放在 output_files/linux 路径下。
- 3. 用 make parallel_bbv_naive 命令，调用 LA_EMU 执行每一个 vmlinux，生成 bbv 向量，存放在 output_files/simpoint 路径下。
- 4. 用 make parallel_simpoint 命令，对每个 bbv 向量进行聚类。
- 5. 用 make parallel_ckpt 命令，生成 simpoint checkpoint，存放在 output_files/simpoint 路径下。

在进行第3步前，建议用 `scripts/batch_run_linux.py` 先用 la_emu 跑一遍生成的linux，确认没有问题。
一个测试点执行完毕后，如果打印 `xxyyzz-SUCCESS` 则认为没有问题，如果打印 `xxyyzz-FAILURE` 则认为存在问题。具体可以参考 `init.c` 代码。

## 其它
- 本项目认为用 `init.c` 编译出的 init 为linux 启动后运行的第一个进程，因此在 linux 的 dts 中需要指定 /init 为第一个执行的进程。
- `init.c` 中使用 `ibar 64` 作为 la_emu 开始执行任务的起点（如记录 bbv，根据 bbv 生成 checkpoint 等任务），使用 `ibar 65` 结束 la_emu 运行。
### Warm-Up
处理器中的 Cache、MMU、分支预测器的冷启动会影响性能评估的准确性，因此需要进行 Warm-Up，对 Cache、MMU、分支预测器进行数据预热。 具体实现方式为提前多执行 W (Warmup length) 条指令，例如：一个预期的 Checkpoint，时间节点为 N，采样区间长度(SM_INTERVAL参数)为I，预热长度为 W。真正生成的 Checkpoint 节点为 N-W，处理器执行时，需要执行 (N-W，N+I) ， 即 W+I 条指令。收集性能数据时需要舍去 (N-M, N) 部分，只收集 （N，N+I）部分的性能数据。 需要注意的是，我们默认设置了W=I（在LIBSIMPOINT 中）。如果需要改变，需要改源码额外调整。

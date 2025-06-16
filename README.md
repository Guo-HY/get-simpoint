# get-simpoint 
基于 la_emu 生成 spec cpu 的 Deterministic Checkpoint Simpoint。

## 使用方法

修改 Makefile：
- 设置 `COMPILER_HOME` 为 LoongArch 编译器路径，`SPEC_HOME` 为 speccpu2006 的根目录，`LA_EMU_HOME` 为 la_emu 的根目录，`LINUX_HOME` 为 linux 根目录。
- 设置 `spec06.run` 为 `benchspec/CPU2006/*/run` 下要跑的目录名字（如 `run_base_ref_none.0000`），设置`spec06.list` 为所有要跑的测试点。
- 如果 spec06 二进制为静态链接，则设置 `LD_SO` 为空。如果 spec06 二进制为动态链接，则需设置 `LD_SO` 为 spec06 二进制运行时所需的动态链接器绝对路径，并将 Makefile 中 `$(BASE_RAMFS_OUTDIR)/.gen: $(INIT_SRCS)` 这个目标下的 `cp -a $(COMPILER_HOME)/sysroot/* $(BASE_RAMFS_OUTDIR)/` 这个注释打开，将编译器目录下的 LoongArch 架构动态库复制到 ramfs 中。需要注意编译器中动态库的具体路径在不同版本编译器中不同。
- 后续的 `LA_EMU`，`LIB*` 这几个变量需要确认其指向的二进制都存在。
- `LINUX_CFG` 和 `LINUX_CFG_PATH` 设置使用的 linux config 文件的名称和路径。注意我们默认 linux 的配置为编译linux 时将 ramfs （以及DTS）打包在内核中，因此后续的 `%.vmlinux_config` 目标下会用 sed 命令修改 config 文件的 `CONFIG_INITRAMFS_SOURCE` 这个配置。建议使用本项目批量生成 vmlinux 前，先手动通过 make vmlinux 制作一个 vmlinux，确定其可以在 la_emu 上正常运行。
- `SIMPOINT` 指向 simpoint 二进制路径，需要提前进入 `projects/SimPoint3.2` 执行 make 生成这个二进制。`SM_INTERVAL` 为 simpoint 采样间隔，`SIMPOINT_FLAGS` 为其它 simpoint 设置。

然后是生成 simpoint 采样点的具体步骤，注意这些步骤应该都需要 sudo 权限，因为在 `gen_spec_ramfs.py` 脚本中需要用 sudo 权限生成一个 `/dev/console` 文件：
- 1. 用 make ramfs 命令批量生成包含所有 `spec06.list` 指定的 spec06 二进制的根文件系统，存放在 output_files/ramfs 路径下。
- 2. 用 make linux 命令，对每个根文件系统生成一个包含它的 vmlinux，存放在 output_files/linux 路径下。
- 3. 用 make bbv_naive 命令，调用 LA_EMU 执行每一个 vmlinux，生成 bbv 向量，存放在 output_files/simpoint 路径下。
- 4. 用 make simpoint 命令，对每个 bbv 向量进行聚类。
- 5. 用 make ckpt 命令，生成 simpoint checkpoint，存放在 output_files/simpoint 路径下。

注意上述命令都有一个对应的 make parallel_* 命令，调用 scripts/ 下的对应脚本并行执行命令，加快速度。

## 其它
- 本项目认为用 `init.c` 编译出的 init 为linux 启动后运行的第一个进程，因此在 linux 的 dts 中需要指定 /init 为第一个执行的进程。
- `init.c` 中使用 `ibar 64` 作为 la_emu 开始执行任务的起点（如记录 bbv，根据 bbv 生成 checkpoint 等任务），使用 `ibar 65` 结束 la_emu 运行。
- 尚未对 spec2017 和 spec2000 进行适配，需要修改 Makefile 中的 spec 二进制搜寻路径，修改 `gen_spec_ramfs.py`。
- 尚未尝试过新世界，不过应该替换一下编译器和 linux 就可以了。
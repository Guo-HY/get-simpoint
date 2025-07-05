# 构建最小化linux内核
- loongarch
- dts启动
- 支持QEMU和LA_EMU

## 步骤
1. 内核源码[https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git)
2. 跨平台工具链[https://mirrors.edge.kernel.org/pub/tools/crosstool/](https://mirrors.edge.kernel.org/pub/tools/crosstool/)
3. config文件，使用本目录下的tiny_config，按需配置`CONFIG_INITRAMFS_SOURCE`和`CONFIG_BUILTIN_DTB_NAME`
4. dts补丁,本目录下的patch，建议使用poweroff.dts，修改`rdinit=/sbin/poweroff`控制init和`memory`控制使用的内存
5. 编译`make ARCH=loongarch CROSS_COMPILE=/opt/loongson/gcc-13.2.0-nolibc/loongarch64-linux/bin/loongarch64-linux- O=build_loongarch -j20 vmlinux`

## qemu运行
```bash
./qemu-system-loongarch64 -M virt -m 16g -smp 1 -kernel ~/kernel/linux/build_loongarch/vmlinux --nographic -serial mon:stdio
```

## LA_EMU运行
```bash
./build/la_emu_kernel -s -w -n -m 16 -k ~/kernel/linux/build_loongarch/vmlinux
```

## FAQ
1. 不同的dts有什么区别？
    - 内核启动参数，内存大小，uart有没有中断，是否有poweroff
2. `0004-mv-load-y-to-0x9000000090200000`这个patch干什么的？
    - 修改内核加载地址，可以支持更大的initrd，目前测试可以约1.8G
3. 关机？
    - QEMU可以ctrl-a + x
    - LA_EMU中，在执行`poweroff -f`，内核会关闭中断进行idle，此时退出。实在不行，`kill -9`

SPEC_HOME = /home/ghy/loongson/benchmark/spec2017/cpu2017v119_loongarch64
spec17r.bench_dir = $(SPEC_HOME)/benchspec/CPU
spec17r.run = run_base_test_loongarch64.Ofast.vec256.0000

spec17r.list += 500.perlbench_r
spec17r.list += 502.gcc_r
spec17r.list += 505.mcf_r
spec17r.list += 520.omnetpp_r
spec17r.list += 523.xalancbmk_r
spec17r.list += 525.x264_r
spec17r.list += 531.deepsjeng_r
spec17r.list += 541.leela_r
spec17r.list += 548.exchange2_r
spec17r.list += 557.xz_r

spec17r.list += 503.bwaves_r
spec17r.list += 507.cactuBSSN_r
spec17r.list += 508.namd_r
spec17r.list += 510.parest_r
spec17r.list += 511.povray_r
spec17r.list += 519.lbm_r
spec17r.list += 521.wrf_r
spec17r.list += 526.blender_r
spec17r.list += 527.cam4_r
spec17r.list += 538.imagick_r
spec17r.list += 544.nab_r
spec17r.list += 549.fotonik3d_r
spec17r.list += 554.roms_r
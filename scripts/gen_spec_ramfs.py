#!/usr/bin/env python3

import sys
import os

def invoke(cmd):
    ret = os.system(cmd)
    if (ret):
        exit(ret)

if len(sys.argv) != 7:
    print(f"usage: {sys.argv[0]} bench_run_dir bench_name rate_num base_ramfs_dir out_dir ld_so")
    exit(1)

bench_run_dir = sys.argv[1]
bench_name = sys.argv[2]
rate_num = int(sys.argv[3])
base_ramfs_dir = sys.argv[4]
out_dir = sys.argv[5]
ld_so = sys.argv[6]

speccmds = []
with open(bench_run_dir + '/speccmds.cmd', 'r') as f:
    speccmds = f.readlines()

bench_id = 1

for line in speccmds:
    parse_cmd = False
    cmd = ''
    options = {}
    prev_word = None
    for word in line.strip().split(' '):
        if parse_cmd:
            if word == '>':
                break
            cmd += ' '
            cmd += word
        elif prev_word:
            options[prev_word] = word
            prev_word = None
        else:
            if word in ['-C', '-E', '-N', '-r']:
                break
            elif word in ['-i', '-o', '-e']:
                prev_word = word
            else:
                cmd = ld_so + ' ./' + os.path.basename(word)
                parse_cmd = True
    if cmd:
        ramfs_name = f"{bench_name}.{bench_id}"
        ramfs_dir = out_dir + '/' + ramfs_name
        print(f"generating {ramfs_name}")
        invoke(f"mkdir -p {ramfs_dir}")
        invoke(f"rm -rf  {ramfs_dir}")
        invoke(f"cp -r {base_ramfs_dir} {ramfs_dir}")
        invoke(f"mkdir {ramfs_dir}/dev")
        invoke(f"sudo mknod -m 600 {ramfs_dir}/dev/console c 5 1")
        with open(ramfs_dir + '/init.cmd', 'w') as f:
            if '-i' in options:
                print("i %s" % (options['-i']), file=f)
            if '-o' in options:
                print("o %s" % (options['-o']), file=f)
            if '-e' in options:
                print("e %s" % (options['-e']), file=f)
            print("d run", file=f)
            print(f"r {rate_num}", file=f)
            print(f"c {cmd}", file=f)
        invoke(f"cp -r {bench_run_dir} {ramfs_dir}/run")
        for i in range(rate_num):
            invoke(f"ln -sf run {ramfs_dir}/run.{i}")
        invoke(f"(cd {ramfs_dir} && find . | cpio -o -H newc) | gzip -3 > {out_dir}/{ramfs_name}.cpio.gz")
        bench_id += 1

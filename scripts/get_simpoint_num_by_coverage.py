import os
import sys
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description="Get simpoint checkpoint num by coverage")
parser.add_argument("--coverage", required=True)
parser.add_argument("--simpoint-dir", required=True)


def list_folders(directory):
    folders = [item.absolute() for item in Path(directory).iterdir() if item.is_dir()]
    return folders

args = parser.parse_args()

coverage = float(args.coverage)
before_total_ckpt_num = 0
after_total_ckpt_num = 0
workloads = list_folders(args.simpoint_dir)
for workload in workloads:
    weights = []
    with open(os.path.join(workload, "weights"), 'r') as f:
        for line in f:
            weights.append(float(line.split()[0]))
    weights.sort(reverse=True)
    before_ckpt_num = len(weights)
    before_total_ckpt_num += before_ckpt_num
    after_ckpt_num = 0
    accum_weight = 0.0
    while accum_weight < coverage:
        accum_weight += weights.pop(0)
        after_ckpt_num += 1
    print(f"{workload}:before_ckpt_num={before_ckpt_num},after_ckpt_num={after_ckpt_num},accum_weight={accum_weight:.{6}f}")
    after_total_ckpt_num += after_ckpt_num

print(f"before_total_ckpt_num={before_total_ckpt_num},after_total_ckpt_num={after_total_ckpt_num}")

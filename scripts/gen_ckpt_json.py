import os
import sys
import argparse
import re
import json

parser = argparse.ArgumentParser(description="Generate simpoint checkpoint json file")
parser.add_argument("--name", required=True, help="name of the output file")
parser.add_argument("--checkpoint", required=True, help="simpoint checkpoint dir path")
parser.add_argument("--sm-interval", required=True, help="simpoint interval")

output = {}
workload_infos = []

def read_weights(weights_path):
    id2weights = {}
    with open(weights_path, 'r') as f:
        for line in f:
            value, key = line.strip().split()
            key = int(key)
            value = float(value)
            id2weights[key] = value
    return id2weights

def read_simpoints(simpoints_path):
    id2interval = {}
    with open(simpoints_path, 'r') as f:
        for line in f:
            value, key = line.strip().split()
            key = int(key)
            value = int(value)
            id2interval[key] = value
    return id2interval

def extract_ckpt_id(checkpoint_name):
    pattern = r"w([0-9\.]+)_(\d+)_icount_(\d+)"
    match = re.match(pattern, checkpoint_name)
    if match:
        weight = float(match.group(1))
        id = int(match.group(2))
        real_icount = int(match.group(3))
    else:
        print("extract_ckpt_id no match, exit")
        exit(1)
    return id

def main():
    args = parser.parse_args()
    
    output["sm_interval"] = args.sm_interval

    root_dir = args.checkpoint

    workloads = [d for d in os.listdir(root_dir) if os.path.isdir(os.path.join(root_dir, d))]

    for workload in workloads:
        workload_path = os.path.join(root_dir, workload)
        simpoints_path = os.path.join(workload_path, "simpoints")
        weights_path = os.path.join(workload_path, "weights")
        id2interval = read_simpoints(simpoints_path)
        id2weights = read_weights(weights_path)
        ckpt_infos = []
        
        checkpoints = [d for d in os.listdir(workload_path) if os.path.isdir(os.path.join(workload_path, d))]
        for checkpoint in checkpoints:
            checkpoint_path = os.path.abspath(os.path.join(workload_path, checkpoint))
            ckpt_id = extract_ckpt_id(checkpoint)
            ckpt_info = {
                "id" : ckpt_id,
                "path" : checkpoint_path,
                "weight" : id2weights[ckpt_id],
                "interval" : id2interval[ckpt_id]
            }
            ckpt_infos.append(ckpt_info)
        
        ckpt_infos = sorted(ckpt_infos, key=lambda x: x['id'])
        workload_info = {
            "name" : workload,
            "simpoints" : ckpt_infos
        }
        workload_infos.append(workload_info)
    
    output["workloads"] = workload_infos
    
    with open(args.name, 'w') as file:
        json.dump(output, file, indent=4)


if __name__ == "__main__":
    main()

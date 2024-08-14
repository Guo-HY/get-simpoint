import os
import sys
import time
import subprocess
import concurrent.futures
import multiprocessing

num_cores = int(multiprocessing.cpu_count() / 2)
simpoint = sys.argv[1]
linux_outdir = sys.argv[2]
simpoint_outdir = sys.argv[3]

def get_simpoint(simpoint_path):
    print("try run " + simpoint_path)
    start_time = time.time()
    try:
        log_file = open(os.path.join(simpoint_path, "simpoint.log"), "w")
        bbv_path = os.path.join(simpoint_path, "bbv.txt")
        simpoints_path = os.path.join(simpoint_path, "simpoints")
        weights_path = os.path.join(simpoint_path, "weights")
        cmd = [simpoint, "-maxK", "30", "-numInitSeeds", "5", "-iters", "1000", "-loadFVFile", bbv_path, "-saveSimpoints", simpoints_path,"-saveSimpointWeights", weights_path]
        print(f"cmd={cmd}")
        result = subprocess.run(cmd, stdout=log_file, stderr=log_file)
        end_time = time.time()
        print(f"finish run {simpoint_path}, spend {end_time - start_time} seconds")

        return f"Finish processing {simpoint_path}"
    except Exception as e:
        end_time = time.time()
        print(f"fail run {simpoint_path}:{str(e)}, spend {end_time - start_time} seconds")
        return f"Error processing {simpoint_path}: {str(e)}"

def main():
    print("detect core num=" + str(num_cores))
    simpoint_paths = [os.path.join(simpoint_outdir, file.rsplit('.', 1)[0]) for file in os.listdir(linux_outdir)]
    
    with concurrent.futures.ProcessPoolExecutor(max_workers=num_cores) as executor:
        results = executor.map(get_simpoint, simpoint_paths)

if __name__ == "__main__":
    main()
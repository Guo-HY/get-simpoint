import os
import sys
import time
import subprocess
import concurrent.futures
import multiprocessing

num_cores = int(multiprocessing.cpu_count() / 2)
la_emu_path = sys.argv[1]
linux_outdir = sys.argv[2]
libbbvnaive = sys.argv[3]
simpoint_outdir = sys.argv[4]
sm_interval = sys.argv[5]


def get_bbv_naive(linux_path, bbv_path):
    print("try run " + linux_path)
    start_time = time.time()
    try:
        os.makedirs(os.path.dirname(bbv_path), exist_ok=True)
        log_file = open(os.path.join(os.path.dirname(bbv_path), "bbv_naive.log"), "w")
        cmd = [la_emu_path, "-m", "16", "-z", "-k", linux_path, "-p", f"{libbbvnaive},bbv={bbv_path},gz=1,interval={sm_interval},ibar0x40=1"]
        print(f"cmd={cmd}")
        result = subprocess.run(cmd, stdout=log_file, stderr=log_file)
        end_time = time.time()
        print(f"finish run {linux_path}, spend {end_time - start_time} seconds")

        return f"Finish processing {linux_path}"
    except Exception as e:
        end_time = time.time()
        print(f"fail run {linux_path}:{str(e)}, spend {end_time - start_time} seconds")
        return f"Error processing {linux_path}: {str(e)}"

def main():
    print("detect core num=" + str(num_cores))
    linux_paths = [os.path.join(linux_outdir, file) for file in os.listdir(linux_outdir)]
    bbv_paths = [os.path.join(simpoint_outdir, file.rsplit('.', 1)[0], "bbv.gz") for file in os.listdir(linux_outdir)]
    
    with concurrent.futures.ProcessPoolExecutor(max_workers=num_cores) as executor:
        results = executor.map(get_bbv_naive, linux_paths, bbv_paths)

if __name__ == "__main__":
    main()
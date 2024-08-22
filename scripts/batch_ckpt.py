import os
import sys
import time
import subprocess
import concurrent.futures
import multiprocessing

num_cores = int(multiprocessing.cpu_count() / 2)
la_emu_path = sys.argv[1]
linux_outdir = sys.argv[2]
libsimpoint = sys.argv[3]
simpoint_outdir = sys.argv[4]
sm_interval = sys.argv[5]

def get_ckpt(linux_path, simpoints_path, weights_path):
    print("try run " + linux_path)
    start_time = time.time()
    try:
        save_dir = os.path.dirname(simpoints_path)
        os.makedirs(save_dir, exist_ok=True)
        log_file = open(os.path.join(save_dir, "ckpt.log"), "w")
        cmd = [la_emu_path, "-m", "16", "-z", "-k", linux_path, "-p", f"{libsimpoint},path={save_dir},interval={sm_interval},simpoints={simpoints_path},weights={weights_path},ibar0x40=1"]
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
    simpoints_paths = [os.path.join(simpoint_outdir, file.rsplit('.', 1)[0], "simpoints") for file in os.listdir(linux_outdir)]
    weights_paths = [os.path.join(simpoint_outdir, file.rsplit('.', 1)[0], "weights") for file in os.listdir(linux_outdir)]
    
    with concurrent.futures.ProcessPoolExecutor(max_workers=num_cores) as executor:
        results = executor.map(get_ckpt, linux_paths, simpoints_paths, weights_paths)

if __name__ == "__main__":
    main()
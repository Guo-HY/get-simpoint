import os
import sys
import time
import subprocess
import concurrent.futures
import multiprocessing

num_cores = int(multiprocessing.cpu_count() / 2)
la_emu_path = sys.argv[1]
linux_folder_path = sys.argv[2]

def run_linux(file_path):
    print("try run " + file_path)
    start_time = time.time()
    try:
        log_file = open(os.path.basename(file_path) + ".log", "w")
        cmd = [la_emu_path, "-m", "16", "-z", "-k", file_path]
        print(f"cmd={cmd}")
        result = subprocess.run(cmd, stdout=log_file, stderr=log_file)
        end_time = time.time()
        print(f"finish run {file_path}, spend {end_time - start_time} seconds")

        return f"Finish processing {file_path}"
    except Exception as e:
        end_time = time.time()
        print(f"fail run {file_path}:{str(e)}, spend {end_time - start_time} seconds")
        return f"Error processing {file_path}: {str(e)}"

def main():
    print("detect core num=" + str(num_cores))
    linux_paths = [os.path.join(linux_folder_path, file) for file in os.listdir(linux_folder_path)]

    with concurrent.futures.ProcessPoolExecutor(max_workers=num_cores) as executor:
        results = executor.map(run_linux, linux_paths)

if __name__ == "__main__":
    main()
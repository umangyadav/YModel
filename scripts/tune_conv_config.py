import multiprocessing as mp
import os
import argparse as ap
import subprocess
from time import sleep

def parse_args():
    parser = ap.ArgumentParser()
    parser.add_argument('--rocm-path', type=str, help='Path to rocm e.g /opt/rocm')
    parser.add_argument('--conv-config', type=str, help='Path to Convolution configs')
    args = parser.parse_args()
    return args

def set_miopen_tuning_flag():
    os.environ["MIOPEN_FIND_ENFORCE"]="3"
    os.environ["MIOPEN_ENABLE_LOGGING"]="1"
    os.environ["MIOPEN_LOG_LEVEL"]="6"

if __name__ == "__main__":
    args = parse_args()
    # change current path to rocm_path
    conv_config_file = open(args.conv_config, 'r')
    conv_configs = conv_config_file.readlines()
    conv_config_file.close()
    set_miopen_tuning_flag()
    print("find enforce is set to :", os.environ.get("MIOPEN_FIND_ENFORCE"))
    p_list = []
    for config in conv_configs:
        command_list = config.strip().split()
        # remove solution flag 
        command_list.index("-S")
        try:
            solution_index =  command_list.index("-S")
            command_list.pop(solution_index)
            command_list.pop(solution_index)
        except:
            print("MIOpenDriver command doesn't have Solution Index\n")
        # add search flag, shouldn't be necessary as MIOPEN_FIND_ENFORCE is set
        command_list.append('--search')
        command_list.append('1')
        p = subprocess.Popen(args=command_list, cwd=args.rocm_path)
        p_list.append(p)
        p.wait()
    for p in p_list:
        p.wait()

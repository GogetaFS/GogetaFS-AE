#!/usr/bin/env python3
import pandas as pd
import os

# with open("./avg-result-calculated-in-paper", "r") as f:
with open("./table-calculated", "r") as f:
    df = pd.read_csv(f, delim_whitespace=True, engine='python')



sys_num = 4
blk_sizes = [4096, 2097152]

for blk_idx, blk_size in enumerate(blk_sizes):
    out_name = "latex-table-{}".format(blk_size)
    
    os.system("echo > {}".format(out_name))
    os.system("cat latex-table-template | tee {} > /dev/null".format(out_name))
    
    REGION_NEW = df.iloc[blk_idx * sys_num + 0]
    FDM_NEW = df.iloc[blk_idx * sys_num + 1]
    REGION_AGE = df.iloc[blk_idx * sys_num + 2 * sys_num]
    FDM_AGE = df.iloc[blk_idx * sys_num + 2 * sys_num + 1]

    def replace(a, b):
        cmd = "sed -i 's/{}/{}/g' {} > /dev/null".format(a, b, out_name)
        os.system(cmd)

    targets = [("REGION-NEW", REGION_NEW), ("REGION-AGE", REGION_AGE), ("ENTRY-NEW", FDM_NEW), ("ENTRY-AGE", FDM_AGE)]

    cols_alias = {
        "read_amp": "RAMP",  
        "write_amp": "WAMP",
        "throughput(MiB/s)": "BW",
        "latency(ns)": "LAT"
    }

    for target in targets:
        for col in ["read_amp", "write_amp", "throughput(MiB/s)", "latency(ns)"]:
            target_name = target[0]
            target_df = target[1]
            key = "{" + target_name + "-" + cols_alias[col] + "}"
            replace(key, round(float(target_df[col]), 1))

            if col == "read_amp":
                key = "{" + target_name + "-" + "RPB" + "}"
                if float(target_df[col]) < 0:
                    replace(key, r"$\\sim$0")
                else:
                    replace(key, round(float(target_df[col]), 1))
            elif col == "write_amp":
                key = "{" + target_name + "-" + "WPB" + "}"
                if float(target_df[col]) < 0:
                    replace(key, r"$\\sim$0")
                else:
                    replace(key, round(float(target_df[col]), 1))
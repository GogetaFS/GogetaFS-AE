#!/usr/bin/env python3
from traceback import print_tb
import pandas as pd
import os

# with open("./avg-result-in-paper", "r") as f:
with open("./performance-comparison-table", "r") as f:
    df = pd.read_csv(f, delim_whitespace=True, engine='python')

os.system("echo > latex-table")
os.system("cat latex-table-template | tee latex-table > /dev/null")

LIGHT_DEDUP_NORMAL = df.iloc[0:5]
LIGHT_DEDUP_FAIL = df.iloc[5:10]
NOVA_NORMAL = df.iloc[10:15]
NOVA_FAIL = df.iloc[15:20]
FDM_NORMAL = df.iloc[20:25]
FDM_FAIL = df.iloc[25:30]

def replace(a, b):
    cmd = "sed -i 's/{}/{}/g' latex-table > /dev/null".format(a, b)
    os.system(cmd)

targets = [("NOVA-FAIL", NOVA_FAIL), ("NOVA-NORMAL", NOVA_NORMAL), ("Light-Dedup-NORMAL", LIGHT_DEDUP_NORMAL), ("Light-Dedup-FAIL", LIGHT_DEDUP_FAIL), ("FDM-NORMAL", FDM_NORMAL), ("FDM-FAIL", FDM_FAIL), ("NOVA-UMOUNT", NOVA_NORMAL), ("Light-Dedup-UMOUNT", LIGHT_DEDUP_NORMAL), ("FDM-UMOUNT", FDM_NORMAL)]

for target in targets:
    for idx, workload in enumerate(["fio", "cp", "home-2022-fall-50.hitztrace", "webmail+online.cs.fiu.edu-110108-113008.1-21.blkpare", "cheetah.cs.fiu.edu-110108-113008.1.blkpares"]):
        remap = {
            "fio": "FIO",
            "cp": "CP",
            "home-2022-fall-50.hitztrace": "HM",
            "webmail+online.cs.fiu.edu-110108-113008.1-21.blkpare": "MA",
            "cheetah.cs.fiu.edu-110108-113008.1.blkpares": "VM"
        }
        
        target_name = target[0]
        target_df = target[1]
        rename = remap[workload]
        key = "{" + target_name + "-" + rename + "}"
        
        if target_name.find("UMOUNT") != -1:
            replace(key, round(float(target_df.iloc[idx]["umount_time"]), 2))
        else:
            replace(key, round(float(target_df.iloc[idx]["recovery"]), 2))
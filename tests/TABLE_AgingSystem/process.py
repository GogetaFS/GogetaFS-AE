#!/usr/bin/env python3

import csv
import pandas as pd

output_table = 'table-calculated'

def table_alias(table:str):
    return "FreshSystem" if table == "newly_table" else "AgedSystem"

def process_table(table:str, writer):
    with open(table, 'r') as i_f:
        reader = csv.DictReader(i_f, delimiter=' ')
        content = []
        
        with open(table, "r") as f:
            df = pd.read_csv(f, delim_whitespace=True, engine='python')
        blks = df['block_size'].unique()
        
        for blk_idx, blk in enumerate(blks):
            for row in reader:
                content.append(row)
        
            base = content[0 + blk_idx * 5]
            region = content[1 + blk_idx * 5]
            fdm = content[2 + blk_idx * 5]
            fdm_32 = content[3 + blk_idx * 5]
            fdm_super = content[4 + blk_idx * 5]
            
            
            def calc_amp(table, base, row, type:str):
                if table == "newly_table":
                    file_size = int(row['file_size'])
                elif table == "aging_table":
                    file_size = int(row['file_size']) // 2
                num_blks = file_size * 1024 * 256
                return ((int(row[type]) - int(base[type])) / num_blks)
            
            def calc_bw(table, row):
                if table == "newly_table":
                    file_size = int(row['file_size'])
                elif table == "aging_table":
                    file_size = int(row['file_size']) // 2
                return (file_size * 1024) / (float(row['time']) / 1000)
            
            def calc_lat(table, row):
                if table == "newly_table":
                    file_size = int(row['file_size'])
                elif table == "aging_table":
                    file_size = int(row['file_size']) // 2
                num_blks = file_size * 1024 * 256
                return (float(row['time']) * 1000 * 1000) / num_blks

            writer.writerow([table_alias(table), "Region", blk, calc_amp(table, base, region, "read"), calc_amp(table, base, region, "write"), calc_bw(table, region), calc_lat(table, region)])

            writer.writerow([table_alias(table), "FDM", blk, calc_amp(table, base, fdm, "read"), calc_amp(table, base, fdm, "write"), calc_bw(table, fdm), calc_lat(table, fdm)])
            
            writer.writerow([table_alias(table), "FDM_32", blk, calc_amp(table, base, fdm_32, "read"), calc_amp(table, base, fdm_32, "write"), calc_bw(table, fdm_32), calc_lat(table, fdm_32)])
            
            writer.writerow([table_alias(table), "FDM-Super", blk, calc_amp(table, base, fdm_super, "read"), calc_amp(table, base, fdm_super, "write"), calc_bw(table, fdm_super), calc_lat(table, fdm_super)])
        
with open(output_table, 'w') as o_f:
    writer = csv.writer(o_f, delimiter=' ')
    writer.writerow(["system", "metadata_layout", "blk_sz", "read_amp", "write_amp", "throughput(MiB/s)", "latency(ns)"])
    process_table("newly_table", writer)
    process_table("aging_table", writer)
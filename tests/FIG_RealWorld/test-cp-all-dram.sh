#!/usr/bin/env bash

source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA
NUM_JOBS=( 1 2 3 4 5 6 7 8 )

FILE_SYSTEMS=( "Light-Dedup-J-64bits" "Light-Dedup-J-64bits-xxhash" "Light-Dedup-J" "Light-Dedup-J-Super" "Light-Dedup-Improve" "DeNOVA" "NV-Dedup" "NOVA-Improve")
SETUPS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nvdedup.sh" "setup_nova.sh" )
BRANCHES=( "light-fs-dedup-64bit-fp" "light-fs-dedup-64bit-xxhash" "light-fs-dedup" "light-fs-dedup-super" "nova-pipe-dedup" "denova" "43d52fb329d55c031d6f2199ca7877660aa3f610" "nova-pipe" )

BLKS=( 1 512 )

TABLE_NAME="$ABS_PATH/performance-comparison-table-cp-all-dram"
table_create "$TABLE_NAME" "file_system blks num_job first_bw second_bw"

STEP=0

# warm up cache
bash ../../nvm_tools-J/"${SETUPS[$STEP]}" "${BRANCHES[$STEP]}" "0"
BW1=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-1" "1")
BW2=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-2" "1")

# start test
loop=1
if [ "$1" ]; then
    loop=$1
fi

for ((i=1; i <= loop; i++))
do
    for blk in "${BLKS[@]}"; do
        STEP=0
        for file_system in "${FILE_SYSTEMS[@]}"; do
            for job in "${NUM_JOBS[@]}"; do

                bash ../../nvm_tools-J/"${SETUPS[$STEP]}" "${BRANCHES[$STEP]}" "0"
                # Code Here
                BW1=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-1" "$job" $((blk * 4096)))
                BW2=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-2" "$job" $((blk * 4096)))
                
                table_add_row "$TABLE_NAME" "$file_system $blk $job $BW1 $BW2"     
            done
            STEP=$((STEP + 1))
        done
    done
done

#!/usr/bin/env bash

source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA
NUM_JOBS=( 1 8 )

# I/O: 20.84 GiB
# Dup Ratio: 100%
# Unique: 20.84 GiB
# 20.84*1024*1024 KB / 4 KB = 5463080 key-value pairs
# half 24~B keys: 5463080 * 24 / 2 / 1024 / 1024 = 62.4 MiB (64 MiB)
# all 24~B keys: 5463080 * 24 / 1024 / 1024 = 124.8 MiB (128 MiB)
# three quarters of 48~B nodes: 5463080 * 48 * 3 / 4 / 1024 / 1024 = 187.2 MiB (192 MiB)
# all 48~B nodes: 5463080 * 48 / 1024 / 1024 = 249.6 MiB (256 MiB)

SWAP_TIME=1
SWAP_MEM_SIZES=( $((1024 * 1024 * 64)) $((1024 * 1024 * 128)) $((1024 * 1024 * 192)) $((1024 * 1024 * 256)) )

FILE_SYSTEMS=( "Light-Dedup-J-Regulate" "Light-Dedup-J-PM-Table" "Light-Dedup-J-PM-Table-P" )
SETUPS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "light-fs-dedup-regulate" "light-fs-dedup-pm-table" "light-fs-dedup-pm-table-persistence")

BLKS=( 1 512 )

TABLE_NAME="$ABS_PATH/performance-comparison-table-cp-hybrid"
table_create "$TABLE_NAME" "file_system blks num_job swap_mem first_bw second_bw"

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
                for swap_mem in "${SWAP_MEM_SIZES[@]}"; do
                    bash ../../nvm_tools-J/"${SETUPS[$STEP]}" "${BRANCHES[$STEP]}" "0" "$SWAP_TIME" "$swap_mem"
                    
                    # Code Here
                    BW1=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-1" "$job" $((blk * 4096)))
                    BW2=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-2" "$job" $((blk * 4096)))
                    
                    table_add_row "$TABLE_NAME" "$file_system $blk $job $swap_mem $BW1 $BW2" 
                done
            done
            STEP=$((STEP + 1))
        done
    done
done

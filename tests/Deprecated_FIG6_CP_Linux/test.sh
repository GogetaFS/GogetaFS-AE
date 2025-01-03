#!/usr/bin/env bash

source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA
NUM_JOBS=( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 )

FILE_SYSTEMS=( "Light-Dedup" "Light-Dedup(SHA256)-SP" "Light-Dedup(SHA256)" "NV-Dedup" "NOVA")
SETUPS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nvdedup.sh" "setup_nova.sh")
BRANCHES=( "master" "sha256" "sha256-no-prefetch-speculation" "master" "original" )

TABLE_NAME="$ABS_PATH/performance-comparison-table"
table_create "$TABLE_NAME" "file_system num_job first_bw second_bw"

STEP=0

# warm up SSD
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
    STEP=0
    for file_system in "${FILE_SYSTEMS[@]}"; do
        for job in "${NUM_JOBS[@]}"; do

            bash ../../nvm_tools-J/"${SETUPS[$STEP]}" "${BRANCHES[$STEP]}" "0"
            # Code Here
            BW1=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-1" "$job")
            BW2=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-2" "$job")
            
            table_add_row "$TABLE_NAME" "$file_system $job $BW1 $BW2"     
        done
        STEP=$((STEP + 1))
    done
done

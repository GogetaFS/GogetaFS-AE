#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA

FILE_SIZE=( $((128)) ) # 128 * 1024
NUM_JOBS=(1 2 4 8 16)      

FILE_SYSTEMS=( "Volatile-FP" "Single-Allocator" "Percore-Allocator" )
TIMERS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "volatile-fpentry" "serial-seq" "master" )
TABLE_NAME="$ABS_PATH/table"
PMEM_ID=0x0020
if [ "$1" ]; then
    PMEM_ID=$1
fi

table_create "$TABLE_NAME" "file_system file_size num_job read write t"

loop=1
if [ "$2" ]; then
    loop=$2
fi

for ((i=1; i <= loop; i++))
do
    for job in "${NUM_JOBS[@]}"; do
        STEP=0
        for file_system in "${FILE_SYSTEMS[@]}"; do
            for fsize in "${FILE_SIZE[@]}"; do
                EACH_SIZE=$(split_workset "$fsize" "$job")
                TIMER=${TIMERS[$STEP]}
                
                bash ../../nvm_tools-J/"$TIMER" "${BRANCHES[$STEP]}" "0"
                OUTPUT=$(bash ../../nvm_tools-J/percore_amount.sh "/mnt/pmem0" "$job" "${EACH_SIZE}" "$PMEM_ID")
                SECOND_TIME=$(echo "$OUTPUT" | grep SecondTime | awk '{print $2}')
                SECOND_READ=$(echo "$OUTPUT" | grep SecondRead | awk '{print $2}')
                SECOND_WRITE=$(echo "$OUTPUT" | grep SecondWrite | awk '{print $2}')

                table_add_row "$TABLE_NAME" "$file_system $fsize $job $SECOND_READ $SECOND_WRITE $SECOND_TIME"
            done
            STEP=$((STEP + 1))
        done
    done 
done 



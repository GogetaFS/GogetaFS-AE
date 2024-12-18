#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA
FILE_SIZE=( $((128)) ) # 32 GB
# FILE_SIZE=( $((1)) ) # 1 GB
BSS=( 4096 $((2 * 1024 * 1024)) )
NUM_JOBS=( 1 )

FILE_SYSTEMS=( "Volatile-FP" "Light-Dedup-Improve" "Light-Dedup-J-64bits" "Light-Dedup-J" "Light-Dedup-J-Super" )
TIMERS=( "aging_amount.sh" "aging_amount.sh" "aging_amount.sh" "aging_amount.sh" "aging_amount.sh" )
BRANCHES=( "volatile-fpentry" "nova-pipe-dedup" "light-fs-dedup-64bit-fp" "light-fs-dedup" "light-fs-dedup-super" )

PMEM_ID=0x0020
if [ "$1" ]; then
    PMEM_ID=$1
fi

AGING_RATIO=(50)

TABLE_NAME_NEWLY="$ABS_PATH/newly_table"
TABLE_NAME_AGING="$ABS_PATH/aging_table"
table_create "$TABLE_NAME_AGING" "file_system file_size block_size read write time"
table_create "$TABLE_NAME_NEWLY" "file_system file_size block_size read write time"

loop=1
if [ "$2" ]; then
    loop=$2
fi

for ((i=1; i <= loop; i++))
do
    for job in "${NUM_JOBS[@]}"; do
        for age in "${AGING_RATIO[@]}"; do
            for bs in "${BSS[@]}"; do
                STEP=0
                for file_system in "${FILE_SYSTEMS[@]}"; do
                    for fsize in "${FILE_SIZE[@]}"; do
                        TIMER=${TIMERS[$STEP]}
                        
                        OUTPUT=$(bash ../../nvm_tools-J/"$TIMER" "$job" "${EACH_SIZE}"M 0 "${BRANCHES[$STEP]}" "$fsize" "$age" "$bs" "$PMEM_ID")

                        READS=$(echo "$OUTPUT" | grep MediaReads | awk '{print $2}')
                        WRITES=$(echo "$OUTPUT" | grep MediaWrites | awk '{print $2}')
                        NewlyWriteTime=$(echo "$OUTPUT" | grep NewlyWriteTime | awk '{print $2}')
                        AgingWriteTime=$(echo "$OUTPUT" | grep AgingWriteTime | awk '{print $2}')
                        NewlyRead=$(echo "$READS" | sed -n "1p") 
                        AgingRead=$(echo "$READS" | sed -n "2p") 
                        NewlyWrite=$(echo "$WRITES" | sed -n "1p") 
                        AgingWrite=$(echo "$WRITES" | sed -n "2p") 
                        
                        table_add_row "$TABLE_NAME_NEWLY" "$file_system ${fsize} $bs $NewlyRead $NewlyWrite $NewlyWriteTime"     
                        
                        table_add_row "$TABLE_NAME_AGING" "$file_system ${fsize} $bs $AgingRead $AgingWrite $AgingWriteTime"
        
                    done
                    STEP=$((STEP + 1))
                done
            done
        done
    done 
done

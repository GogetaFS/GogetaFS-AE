#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA

SWAP_TIME=1

# I/O: 43.92 GiB
# Dup Ratio: 69.03%
# Unique: 13.6 GiB = 43.92 GiB * 0.31
# 13.6*1024*1024 KB / 4 KB = 3565158 key-value pairs
# half 24~B keys: 3565158 * 24 / 2 / 1024 / 1024 = 40.8 MiB
# all 24~B keys: 3565158 * 24 / 1024 / 1024 = 81.6 MiB
# three quarters of 48~B nodes: 3565158 * 48 * 3 / 4 / 1024 / 1024 = 144.6 MiB

HOME_SWAP=($((1024 * 1024 * 48)) $((1024 * 1024 * 96)) $((1024 * 1024 * 144)) $((1024 * 1024 * 192)))


FILE_SYSTEMS=( "Light-Dedup-J-Regulate" "Light-Dedup-J-PM-Table" "Light-Dedup-J-PM-Table-P" )
SETUPS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "light-fs-dedup-regulate" "light-fs-dedup-pm-table" "light-fs-dedup-pm-table-persistence")
MODES=( "a" "a" "a" )

NAMES=( "homes_fit85.hitsztrace" )
TRACES=( "/mnt/sdb/HITSZ_LAB_Traces/homes_fit85.hitsztrace" )
FMTS=( "hitsz" )

MAX_C_BLKS=( 1 512 )
NUM_JOBS=( 1 8 )

TABLE_NAME="$ABS_PATH/performance-comparison-table-trace-hybrid"
table_create "$TABLE_NAME" "file_system trace cblks job swap_mem bandwidth(MiB/s)"

loop=1
if [ "$1" ]; then
    loop=$1
fi

for ((i=1; i <= loop; i++))
do
    for cblks in "${MAX_C_BLKS[@]}"; do
        for job in "${NUM_JOBS[@]}"; do
            STEP=0
            for file_system in "${FILE_SYSTEMS[@]}"; do
                TRACE_ID=0
                for TRACE in "${TRACES[@]}"; do
                    if (( TRACE_ID == 0 )); then
                        SWAP_MEM_SIZES=("${HOME_SWAP[@]}")
                    elif (( TRACE_ID == 1 )); then
                        SWAP_MEM_SIZES=("${WEB_MAIL_SWAP[@]}")
                    elif (( TRACE_ID == 2 )); then
                        SWAP_MEM_SIZES=("${CHEETAH_SWAP[@]}")
                    fi
                    
                    for swap_mem in "${SWAP_MEM_SIZES[@]}"; do
                        bash ../../nvm_tools-J/"${SETUPS[$STEP]}" "${BRANCHES[$STEP]}" "0" $SWAP_TIME "$swap_mem"
                        
                        sleep 1

                        BW=$(../../nvm_tools-J/replay -f "$TRACE" -d /mnt/pmem0/ -o "${MODES[$STEP]}" -g null -t "$job" -c "$cblks" -m "${FMTS[$TRACE_ID]}" | grep "Bandwidth" | awk '{print $9}')

                        table_add_row "$TABLE_NAME" "$file_system ${NAMES[$TRACE_ID]} $cblks $job $swap_mem $BW"  
                    done
                    TRACE_ID=$((TRACE_ID + 1))
                done
                STEP=$((STEP + 1))
            done
        done
    done
done


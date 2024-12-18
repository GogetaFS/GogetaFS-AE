#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA

FILE_SYSTEMS=( "Light-Dedup-J-Regulate" "Light-Dedup-J-Log-Regulate" "Light-Dedup-J-PM-ALL" "Light-Dedup-J-PM-ALL-P" "DeNOVA" "NOVA-Improve")
SETUPS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh")
BRANCHES=( "light-fs-dedup-regulate" "light-fs-dedup-logging-regulate" "light-fs-dedup-pm-all" "light-fs-dedup-pm-all-persistence" "denova" "nova-pipe")
MODES=( "a" "a" "a" "a" "a" "a")


NAMES=( "smart_fit85.hitsztrace" )
TRACES=( "/mnt/sdb/HITSZ_LAB_Traces/smart_fit85.hitsztrace" )
FMTS=( "hitsz" )

MAX_C_BLKS=( 1 )
NUM_JOBS=( 1 4 )

TABLE_NAME="$ABS_PATH/performance-comparison-table-trace-all-pm"
table_create "$TABLE_NAME" "file_system trace cblks job bandwidth(MiB/s)"

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
                    if [[ "${file_system}" == *"Regulate"* ]]; then
                        SWAP_TIME=1
                        swap_mem=0
                        bash ../../nvm_tools-J/"${SETUPS[$STEP]}" "${BRANCHES[$STEP]}" "0" $SWAP_TIME "$swap_mem"
                        
                        sleep 1

                        BW=$(../../nvm_tools-J/replay -f "$TRACE" -d /mnt/pmem0/ -o "${MODES[$STEP]}" -g null -t "$job" -c "$cblks" -m "${FMTS[$TRACE_ID]}" | grep "Bandwidth" | awk '{print $9}')

                        table_add_row "$TABLE_NAME" "$file_system ${NAMES[$TRACE_ID]} $cblks $job $BW"  
                    else
                        bash ../../nvm_tools-J/"${SETUPS[$STEP]}" "${BRANCHES[$STEP]}" "0"
                        
                        sleep 1

                        BW=$(../../nvm_tools-J/replay -f "$TRACE" -d /mnt/pmem0/ -o "${MODES[$STEP]}" -g null -t "$job" -c "$cblks" -m "${FMTS[$TRACE_ID]}" | grep "Bandwidth" | awk '{print $9}')

                        table_add_row "$TABLE_NAME" "$file_system ${NAMES[$TRACE_ID]} $cblks $job $BW"  
                    fi
                    
                    TRACE_ID=$((TRACE_ID + 1))
                done
                STEP=$((STEP + 1))
            done
        done
    done
done


#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA
FILE_SIZE=( $((32 * 1024)) ) # 128 * 1024
NUM_JOBS=( 8 )

FILE_SYSTEMS=( "Light-Dedup-NORMAL" "Light-Dedup-FAILURE" "NOVA-OPT-NORMAL" "NOVA-OPT-FAILURE" "Light-Dedup-J-64bits-NORMAL" "Light-Dedup-J-64bits-FAILURE" )
SETUPS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "nova-pipe-dedup" "nova-pipe-dedup-failure" "nova-pipe" "nova-pipe-failure" "light-fs-dedup-64bit-fp" "light-fs-dedup-64bit-fp-failure" )
MODES=( "a" "a" "a" "a" "a" "a" )

NAMES=( "fio" "cp" "homes-2022-fall-50.hitsztrace" "webmail+online.cs.fiu.edu-110108-113008.1-21.blkparse" "cheetah.cs.fiu.edu-110108-113008.1.blkparse" )
TRACES=( "fio" "cp" "/mnt/sdb/HITSZ_LAB_Traces/homes-2022-fall-50.hitsztrace" "/mnt/sdb/FIU_Traces/webmail+online.cs.fiu.edu-110108-113008.1-21.blkparse" "/mnt/sdb/FIU_Traces/cheetah.cs.fiu.edu-110108-113008.1.blkparse" )
FMTS=( "" "" "hitsz" "fiu" "fiu" )

TABLE_NAME="$ABS_PATH/performance-comparison-table"
table_create "$TABLE_NAME" "file_system workload umount_time recovery"

loop=1
if [ "$1" ]; then
    loop=$1
fi

for ((i=1; i <= loop; i++))
do
    STEP=0
    for file_system in "${FILE_SYSTEMS[@]}"; do
        for fsize in "${FILE_SIZE[@]}"; do
            for job in "${NUM_JOBS[@]}"; do
                TRACE_ID=0
                for TRACE in "${TRACES[@]}"; do
                    EACH_SIZE=$(split_workset "$fsize" "$job")
                    bash ../../nvm_tools-J/"${SETUPS[$STEP]}" "${BRANCHES[$STEP]}" "0"

                    if [[ "${TRACE}" == "fio" ]]; then
                        _=$(bash ../../nvm_tools-J/helper/fio.sh "$job" "${EACH_SIZE}"M 0)
                    elif [[ "${TRACE}" == "cp" ]]; then
                        _=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-1" "$job" $((4096)))
                        BW=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-2" "$job" $((4096)))
                    else
                        _=$(../../nvm_tools-J/replay -f "$TRACE" -d /mnt/pmem0/ -o "${MODES[$STEP]}" -g null -t "$job" -c 1 -m "${FMTS[$TRACE_ID]}")
                    fi

                    UMOUNT_TIME=$( (time sudo umount /mnt/pmem0) 2>&1 | grep real | awk '{print $2}' )
                    RECOVERY_TIME=$( (time sudo mount -t NOVA -o wprotect,data_cow /dev/pmem0 /mnt/pmem0) 2>&1 | grep real | awk '{print $2}' )
                    

                    table_add_row "$TABLE_NAME" "$file_system ${NAMES[$TRACE_ID]} $UMOUNT_TIME $RECOVERY_TIME"
                    TRACE_ID=$((TRACE_ID + 1))    
                done
            done
        done
        STEP=$((STEP + 1))
    done
done


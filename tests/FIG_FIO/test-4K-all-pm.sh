#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA
DUP_RATES=( 0 25 50 75 100 )
FILE_SIZE=($((32 * 1024))) # 32 * 1024
NUM_JOBS=(1 4 )

SWAP_TIME=1
swap_mem=0

FILE_SYSTEMS=( "Light-Dedup-J-Regulate" "Light-Dedup-J-PM-ALL" "Light-Dedup-J-PM-ALL-P" )
TIMERS=( "fio_nova.sh" "fio_nova.sh" "fio_nova.sh" )
SETUPS=(  "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "light-fs-dedup-regulate" "light-fs-dedup-pm-all" "light-fs-dedup-pm-all-persistence" )


TABLE_NAME="$ABS_PATH/performance-comparison-table-4K-all-pm"
table_create "$TABLE_NAME" "file_system dup_rate num_job bandwidth(MiB/s)"

loop=1
if [ "$1" ]; then
    loop=$1
fi

for ((i = 1; i <= loop; i++)); do
    for dup_rate in "${DUP_RATES[@]}"; do
        STEP=0
        for file_system in "${FILE_SYSTEMS[@]}"; do
            for fsize in "${FILE_SIZE[@]}"; do
                for job in "${NUM_JOBS[@]}"; do
                    TIMER=${TIMERS[$STEP]}
                    SETUP=${SETUPS[$STEP]}
                    if [[ "${file_system}" == *"Regulate"* ]]; then
                        if ((dup_rate == 100)); then
                            EACH_SIZE=$(split_workset $((fsize / 2)) "$job")
                            bash ../../nvm_tools-J/"$SETUP" "${BRANCHES[$STEP]}" 0 $SWAP_TIME "$swap_mem"
                            sudo mkdir -p /mnt/pmem0/first
                            _=$(sudo fio -directory=/mnt/pmem0/first -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs=4K -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                            sudo mkdir -p /mnt/pmem0/second
                            BW=$(sudo fio -directory=/mnt/pmem0/second -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs=4K -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                        else
                            EACH_SIZE=$(split_workset "$fsize" "$job")
                            BW=$(bash ../../nvm_tools-J/"$TIMER" "$job" "${EACH_SIZE}"M "$dup_rate" "${BRANCHES[$STEP]}" "0" $SWAP_TIME "$swap_mem" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                            cat /proc/fs/NOVA/pmem0/timing_stats > LOG
                        fi
                    else
                        if ((dup_rate == 100)); then
                            EACH_SIZE=$(split_workset $((fsize / 2)) "$job")
                            bash ../../nvm_tools-J/"$SETUP" "${BRANCHES[$STEP]}" 0
                            sudo mkdir -p /mnt/pmem0/first
                            _=$(sudo fio -directory=/mnt/pmem0/first -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs=4K -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                            sudo mkdir -p /mnt/pmem0/second
                            BW=$(sudo fio -directory=/mnt/pmem0/second -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs=4K -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                        else
                            EACH_SIZE=$(split_workset "$fsize" "$job")
                            BW=$(bash ../../nvm_tools-J/"$TIMER" "$job" "${EACH_SIZE}"M "$dup_rate" "${BRANCHES[$STEP]}" "0" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                            cat /proc/fs/NOVA/pmem0/timing_stats > LOG
                        fi
                    fi
                    

                    table_add_row "$TABLE_NAME" "$file_system $dup_rate $job $BW"
                done
            done
            STEP=$((STEP + 1))
        done
    done
done

#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA
DUP_RATES=( 0 )
FILE_SIZE=( $((32 * 1024)) ) # 128 * 1024
NUM_JOBS=( 1 8 )

# I/O: 32 GiB
# Dup Ratio: 0%
# Unique: 32 GiB
# 32*1024*1024 KB / 4 KB = 8388608 key-value pairs
# half 24~B keys: 8388608 * 24 / 2 / 1024 / 1024 = 96 MiB 
# all 24~B keys: 8388608 * 24 / 1024 / 1024 = 192 MiB
# three quarters of 48~B nodes: 8388608 * 48 * 3 / 4 / 1024 / 1024 = 288 MiB
# all 48~B nodes: 8388608 * 48 / 1024 / 1024 = 384 MiB

SWAP_TIME=1
SWAP_MEM_SIZES=( $((1024 * 1024 * 96)) $((1024 * 1024 * 192)) $((1024 * 1024 * 288)) $((1024 * 1024 * 384)) )


# per block entry mem size: 56B 56B 24B 24B
# max_mem: (32G / 4K) * 56B = 224M
# min_mem: (32G / 4K) * 24B = 96M

FILE_SYSTEMS=( "Light-Dedup-J-Regulate" "Light-Dedup-J-PM-Table" "Light-Dedup-J-PM-Table-P" )
TIMERS=( "fio_nova.sh" "fio_nova.sh" "fio_nova.sh" )
SETUPS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "light-fs-dedup-regulate" "light-fs-dedup-pm-table" "light-fs-dedup-pm-table-persistence")

TABLE_NAME="$ABS_PATH/performance-comparison-table-4K-hybrid"
table_create "$TABLE_NAME" "file_system swap_mem num_job bandwidth(MiB/s)"

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
                    for swap_mem in "${SWAP_MEM_SIZES[@]}"; do
                        TIMER=${TIMERS[$STEP]}
                        SETUP=${SETUPS[$STEP]}
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

                        table_add_row "$TABLE_NAME" "$file_system $swap_mem $job $BW"
                    done
                done
            done
            STEP=$((STEP + 1))
        done
    done
done

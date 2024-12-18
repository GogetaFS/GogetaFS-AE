#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
# FILE_SIZE=( 4096 ) # 4 * 1024 ?
NUM_JOBS=( 1 )
DUP_RATES=( 0 25 50 75 )
FILE_SIZE=($((32 * 1024))) # 32 * 1024
BSS=( 4K 128K 512K 2M )

FILE_SYSTEMS=( "Light-Dedup-J-Log" "Light-Dedup-Improve" "NOVA-Improve" "NV-Dedup" "DeNOVA" "NV-Dedup-Non-Crypto" "DeNOVA-Non-Crypto" "Light-Dedup-J-64bits" )
TIMERS=( "fio_nova.sh" "fio_nova.sh" "fio_nova.sh" "fio_nvdedup.sh" "fio_nova.sh" "fio_nvdedup.sh" "fio_nova.sh"  "fio_nova.sh" )
SETUPS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nvdedup.sh" "setup_nova.sh" "setup_nvdedup.sh" "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "light-fs-dedup-logging" "nova-pipe-dedup" "nova-pipe" "master" "denova" "non-crypto" "denova-non-crypto" "light-fs-dedup-64bit-fp")

mkdir -p "$ABS_PATH"/M_DATA
TABLE_NAME="$ABS_PATH/performance-comparison-table-fio"

table_create "$TABLE_NAME" "system dup_rate bs BW" 

loop=1
if [ "$1" ]; then
    loop=$1
fi

for ((i=1; i <= loop; i++))
do
    for dup_rate in "${DUP_RATES[@]}"; do
        for fsize in "${FILE_SIZE[@]}"; do
            for job in "${NUM_JOBS[@]}"; do
                for bs in "${BSS[@]}"; do
                    STEP=0
                    for branch in "${BRANCHES[@]}"; do
                        EACH_SIZE=$(split_workset "$fsize" "$job")
                        sudo dmesg -C

                        TIMER=${TIMERS[$STEP]}
                        SETUP=${SETUPS[$STEP]}
                        if ((dup_rate == 100)); then
                            EACH_SIZE=$(split_workset $((fsize / 2)) "$job")
                            bash ../../nvm_tools-J/"$SETUP" "${BRANCHES[$STEP]}" 0
                            sudo mkdir -p /mnt/pmem0/first
                            _=$(sudo fio -directory=/mnt/pmem0/first -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs="$bs" -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                            sudo mkdir -p /mnt/pmem0/second
                            sudo dmesg -C
                            BW=$(sudo fio -directory=/mnt/pmem0/second -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs="$bs" -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                        else
                            EACH_SIZE=$(split_workset "$fsize" "$job")
                            BW=$(bash ../../nvm_tools-J/"$TIMER" "$job" "${EACH_SIZE}"M "$dup_rate" "${BRANCHES[$STEP]}" "0" "$bs" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                        fi

                        file_system=${FILE_SYSTEMS[$STEP]}
                        
                        table_add_row "$TABLE_NAME" "$file_system $dup_rate $bs $BW"     

                        STEP=$((STEP + 1))     
                    done   
                done
            done
        done
    done
done

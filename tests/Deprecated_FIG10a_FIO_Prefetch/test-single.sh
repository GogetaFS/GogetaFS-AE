#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
mkdir -p "$ABS_PATH"/M_DATA
FILE_SIZE=( $((64 * 1024)) ) # 128 * 1024
NUM_JOBS=( 1 )

# Single Thread with Breakdown
FILE_SYSTEMS=( "Naive" "Prefetch-Cmp-64" "Prefetch-Cmp-256-64" "Prefetch-Current" "Speculation" "Prefetch-Next" )
TIMERS=( "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "no-prefetch-speculation-precmp" "no-prefetch-speculation-precmp_256B" "no-prefetch-speculation" "prefetch-current" "speculation" "no-transition" )

TABLE_NAME="$ABS_PATH/performance-comparison-table-single"
table_create "$TABLE_NAME" "file_system num_job first_bandwidth(MiB/s) second_bandwidth(MiB/s) second_cmp_lat(ns) second_fp_lat(ns) second_prefetch_lat(ns) second_lookup_lat(ns) second_copy_user(ns) second_others_lat(ns) second_lat(ns)"

VERSIONS="$ABS_PATH/version-single"
table_create "$VERSIONS" "file_system version"

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
                EACH_SIZE=$(split_workset "$fsize" "$job")
                TIMER=${TIMERS[$STEP]}

                VER=$(bash ../../nvm_tools-J/"${TIMER}" "${BRANCHES[$STEP]}" "1" | grep "COMMITID" | sed 's/COMMITID: //g')
                
                sudo mkdir -p /mnt/pmem0/first
                BW1=$(sudo fio -directory=/mnt/pmem0/first -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs=2M -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)

                echo 1 > /proc/fs/NOVA/pmem0/timing_stats  
                
                sudo mkdir -p /mnt/pmem0/second
                BW2=$(sudo fio -directory=/mnt/pmem0/second -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs=2M -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                
                cat /proc/fs/NOVA/pmem0/timing_stats > "$ABS_PATH"/M_DATA/OUTPUT-"$i"
                
                # whole_time=$(( EACH_SIZE * 1000 * 1000 * 1000 / ("$BW2") ))  
                whole_time=$(nova_attr_time_stats "cow_write" "$ABS_PATH"/M_DATA/OUTPUT-"$i")   
                fp_time=$(nova_attr_time_stats "fp_calc" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                lookup_time=$(nova_attr_time_stats "index_lookup" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                cmp_time=$(nova_attr_time_stats "memcmp" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                cmp_user=$(nova_attr_time_stats "cmp_user" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                copy_user=$(nova_attr_time_stats "copy_from_user" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                prefetch_cmp=$(nova_attr_time_stats "prefetch_cmp" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                prefetch_cmp=$((prefetch_cmp))
                prefetch_next_stage1=$(nova_attr_time_stats "prefetch_next_stage_1" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                prefetch_next_stage1=$((prefetch_next_stage1))
                prefetch_next_stage2=$(nova_attr_time_stats "prefetch_next_stage_2" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                prefetch_next_stage2=$((prefetch_next_stage1))
                prefetch_stage1=$(nova_attr_time_stats "prefetch_stage_1" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                prefetch_stage1=$((prefetch_stage1))
                prefetch_stage2=$(nova_attr_time_stats "prefetch_stage_2" "$ABS_PATH"/M_DATA/OUTPUT-"$i")
                prefetch_stage2=$((prefetch_stage2))
                
                prefetch_time=$((prefetch_next_stage1 + prefetch_next_stage2 + prefetch_stage1 + prefetch_stage2))
                cmp_time=$((cmp_time + cmp_user + prefetch_cmp)) 
                others=$((whole_time - fp_time - cmp_time - prefetch_time - copy_user - lookup_time))
                
                table_add_row "$TABLE_NAME" "$file_system $job $BW1 $BW2 $cmp_time $fp_time $prefetch_time $lookup_time $copy_user $others $whole_time" 
                table_add_row "$VERSIONS" "$file_system $VER"    
            done
        done
        STEP=$((STEP + 1))
    done
done


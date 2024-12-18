#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
# FILE_SIZE=( 4096 ) # 4 * 1024 ?
NUM_JOBS=( 1 )
DUP_RATES=( 0 25 50 75 )
FILE_SIZE=($((32 * 1024))) # 32 * 1024
BSS=( 4K 2M )

FILE_SYSTEMS=( "Light-Dedup-J-64bits" "Light-Dedup-Improve"  )
TIMERS=( "fio_nova.sh" "fio_nova.sh" )
SETUPS=( "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "light-fs-dedup-64bit-fp-timing" "nova-pipe-dedup-timing" )

mkdir -p "$ABS_PATH"/M_DATA
TABLE_NAME="$ABS_PATH/performance-comparison-table-fio"

table_create "$TABLE_NAME" "system dup_rate bs whole_time dedup_time fp_time index_time cmp_time table_time io_time fs_time other_time BW" 

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
                        OUTPUT=$ABS_PATH/M_DATA/"$i-$fsize-$job"
                        EACH_SIZE=$(split_workset "$fsize" "$job")
                        sudo dmesg -C

                        TIMER=${TIMERS[$STEP]}
                        SETUP=${SETUPS[$STEP]}
                        if ((dup_rate == 100)); then
                            EACH_SIZE=$(split_workset $((fsize / 2)) "$job")
                            bash ../../nvm_tools-J/"$SETUP" "${BRANCHES[$STEP]}" 1
                            sudo mkdir -p /mnt/pmem0/first
                            _=$(sudo fio -directory=/mnt/pmem0/first -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs="$bs" -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                            sudo mkdir -p /mnt/pmem0/second
                            sudo dmesg -C
                            BW=$(sudo fio -directory=/mnt/pmem0/second -fallocate=none -direct=1 -iodepth 1 -rw=write -ioengine=sync -bs="$bs" -thread -numjobs="$job" -size="${EACH_SIZE}M" -name=test --dedupe_percentage=0 -group_reporting -randseed="$i" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                        else
                            EACH_SIZE=$(split_workset "$fsize" "$job")
                            BW=$(bash ../../nvm_tools-J/"$TIMER" "$job" "${EACH_SIZE}"M "$dup_rate" "${BRANCHES[$STEP]}" "1" "$bs" | grep WRITE: | awk '{print $2}' | sed 's/bw=//g' | ../../nvm_tools-J/to_MiB_s)
                        fi

                        cat /proc/fs/NOVA/pmem0/timing_stats > "$OUTPUT-$branch"

                        whole_time=$(nova_attr_time_stats "cow_write" "$OUTPUT-$branch")
                        
                        
                        fp_time=$(nova_attr_time_stats "fp_calc" "$OUTPUT-$branch")
                        
                        index_lookup_time=$(nova_attr_time_stats "index_lookup" "$OUTPUT-$branch")
                        index_insert_time=$(nova_attr_time_stats "index_insert_new_entry" "$OUTPUT-$branch")
                        index_time=$((index_lookup_time + index_insert_time))

                        cmp_user=$(nova_attr_time_stats "cmp_user" "$OUTPUT-$branch")
                        cmp_user=$((cmp_user))
                        prefetch_cmp=$(nova_attr_time_stats "prefetch_cmp" "$OUTPUT-$branch")
                        prefetch_cmp=$((prefetch_cmp))
                        cmp_time=$(nova_attr_time_stats "memcmp" "$OUTPUT-$branch")
                        cmp_time=$((cmp_time + cmp_user + prefetch_cmp))

                        # FIXME: dedup_time is not accurate as partial I/O is not considered
                        # this might affect CP workload
                        dedup_time=$(nova_attr_time_stats "incr_ref_continuous" "$OUTPUT-$branch")
                        io_time=$(nova_attr_time_stats "memcpy_data_block" "$OUTPUT-$branch") 
                        
                        file_system=${FILE_SYSTEMS[$STEP]}

                        if [[ "${file_system}" == *"Light-Dedup-J-64bits"* ]]; then
                            hit_update_fp2p_time=$(nova_attr_time_stats "hit_incr_ref" "$OUTPUT-$branch")
                            update_fp2p_time=$(nova_attr_time_stats "update_fp2p" "$OUTPUT-$branch")
                            new_fp2p_time=$(nova_attr_time_stats "index_insert_new_entry" "$OUTPUT-$branch")
                            oet_time=$(nova_attr_time_stats "oet" "$OUTPUT-$branch")

                            table_time=$((hit_update_fp2p_time + update_fp2p_time + new_fp2p_time + oet_time))
                            fs_time=$(nova_attr_time_stats "append_file_entry" "$OUTPUT-$branch")
                            other_time=$((whole_time - io_time - fp_time - cmp_time - index_time - table_time - fs_time))
                        elif [[ "${file_system}" == *"Light-Dedup"* ]]; then
                            BASE_BRANCH="light-fs-dedup-64bit-fp-timing"
                            hit_update_fp2p_time=$(nova_attr_time_stats "hit_incr_ref" "$OUTPUT-$BASE_BRANCH")
                            update_fp2p_time=$(nova_attr_time_stats "update_fp2p" "$OUTPUT-$BASE_BRANCH")
                            new_fp2p_time=$(nova_attr_time_stats "index_insert_new_entry" "$OUTPUT-$BASE_BRANCH")
                            base_table_time=$((hit_update_fp2p_time + update_fp2p_time + new_fp2p_time))

                            base_real_dedup_time=$(nova_attr_time_stats "handle_last" "$OUTPUT-$BASE_BRANCH")
                            real_dedup_time=$(nova_attr_time_stats "handle_last" "$OUTPUT-$branch")

                            table_time=$((base_table_time + real_dedup_time - base_real_dedup_time))
                            # fs_time=$(nova_attr_time_stats "append_file_entry" "$OUTPUT-$branch")
                            fs_time=$(nova_attr_time_stats "append_file_entry" "$OUTPUT-$branch")
                            # other_time=$((whole_time - dedup_time - fs_time))
                            other_time=$((whole_time - io_time - fp_time - cmp_time - index_time - table_time - fs_time))
                        fi
                        
                        
                        table_add_row "$TABLE_NAME" "$file_system $dup_rate $bs $whole_time $dedup_time $fp_time $index_time $cmp_time $table_time $io_time $fs_time $other_time $BW"     

                        STEP=$((STEP + 1))     
                    done   
                done
            done
        done
    done
done

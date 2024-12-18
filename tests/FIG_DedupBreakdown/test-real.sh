#!/usr/bin/env bash

# shellcheck source=/dev/null
source "../common.sh"
ABS_PATH=$(where_is_script "$0")
NUM_JOBS=( 1 )
MAX_C_BLKS=( 1 512 )

NAMES=( "cp" "homes-2022-fall-50.hitsztrace" "webmail+online.cs.fiu.edu-110108-113008.1-21.blkparse" "cheetah.cs.fiu.edu-110108-113008.1.blkparse" )
TRACES=( "" "/mnt/sdb/HITSZ_LAB_Traces/homes-2022-fall-50.hitsztrace" "/mnt/sdb/FIU_Traces/webmail+online.cs.fiu.edu-110108-113008.1-21.blkparse" "/mnt/sdb/FIU_Traces/cheetah.cs.fiu.edu-110108-113008.1.blkparse" )
FMTS=( "" "hitsz" "fiu" "fiu" )

FILE_SYSTEMS=( "Light-Dedup-J-64bits" "Light-Dedup-Improve"  )
SETUPS=( "setup_nova.sh" "setup_nova.sh" )
BRANCHES=( "light-fs-dedup-64bit-fp-timing" "nova-pipe-dedup-timing" )
MODES=( "rw" "rw" )

mkdir -p "$ABS_PATH"/M_DATA
TABLE_NAME="$ABS_PATH/performance-comparison-table-real"

table_create "$TABLE_NAME" "system workload bs whole_time dedup_time fp_time index_time cmp_time table_time io_time fs_time other_time BW" 

loop=1
if [ "$1" ]; then
    loop=$1
fi

for ((i=1; i <= loop; i++))
do
    for job in "${NUM_JOBS[@]}"; do
        for cblks in "${MAX_C_BLKS[@]}"; do
            TRACE_ID=0
            for TRACE in "${TRACES[@]}"; do
                STEP=0
                for branch in "${BRANCHES[@]}"; do
                    OUTPUT=$ABS_PATH/M_DATA/"$i-$TRACE_ID-$job"
                    sudo dmesg -C

                    bash ../../nvm_tools-J/"${SETUPS[$STEP]}" "${BRANCHES[$STEP]}" "1"
                    
                    sleep 1

                    if [[ -z "${TRACE}" ]]; then
                        # cp
                        _=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-1" "$job" $((cblks * 4096)))
                        sudo dmesg -C
                        BW=$(bash ./mcp.sh "/usr/src/linux-nova-master" "/mnt/pmem0/src-linux-2" "$job" $((cblks * 4096)))
                    else
                        BW=$(../../nvm_tools-J/replay -f "$TRACE" -d /mnt/pmem0/ -o "${MODES[$STEP]}" -g null -t "$job" -c "$cblks" -m "${FMTS[$TRACE_ID]}" | grep "Bandwidth" | awk '{print $9}')
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

                    io_time=$(nova_attr_time_stats "memcpy_data_block" "$OUTPUT-$branch") 
                    
                    # FIXME: dedup_time is not accurate as partial I/O is not considered
                    # this might affect CP workload
                    dedup_time=$(nova_attr_time_stats "incr_ref_continuous" "$OUTPUT-$branch")
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

                    table_add_row "$TABLE_NAME" "$file_system ${NAMES[$TRACE_ID]} $((cblks * 4096)) $whole_time $dedup_time $fp_time $index_time $cmp_time $table_time $io_time $fs_time $other_time $BW" 

                    STEP=$((STEP + 1))     
                done

                TRACE_ID=$((TRACE_ID + 1))    
            done   
        done
    done
done

if [ ! $3 ]; then
	echo Usage: $0 num_of_threads size dup_rate branch_name measure_timing [swap_time_threashold] [dedup_mem_threshold] [block_sz] [nr_files]
	exit 1
fi

ABSPATH=$(cd "$( dirname "$0" )" && pwd)

function set_pmem () {
    local script=$1
    local pmem=$2
    
    cp "$script" "/tmp/setups" -f
    sed -i "s/pmem0/pmem/g" "$script"
    sed -i "s/pmem/$pmem/g" "$script"
}

function restore_pmem () {
    local script=$1
    
    cp "/tmp/setups" "$script" -f
}


branch_name=$4
measure_timing=$5

cd "$ABSPATH"/../Light-Dedup-J/ || exit

git checkout "$branch_name"
sudo make -j32
sudo bash -c "echo $0 $* > /dev/kmsg"

if [[ "${branch_name}" == *"regulate"* || "${branch_name}" == *"pm-table"* ]]; then
    swap_time_threashold=$6
    dedup_mem_threashold=$7
    sudo bash setup.sh "$measure_timing" "$swap_time_threashold" "$dedup_mem_threashold"
    bash "$ABSPATH"/helper/fio.sh "$1" "$2" "$3" "$8" "$9"
else
    restore_pmem "setup.sh" 
    set_pmem "setup.sh" "pmem0"
    sudo bash setup.sh "$measure_timing"
    restore_pmem "setup.sh" 
    git checkout -- "setup.sh"
    bash "$ABSPATH"/helper/fio.sh "$1" "$2" "$3" "$6" "$7"
fi

cd - || exit


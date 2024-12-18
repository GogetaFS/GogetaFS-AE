if [ ! "$1" ]; then
	echo Usage: "$0" branch_name measure_timing [swap_time_threashold] [dedup_mem_threshold]
	exit 1
fi

ABSPATH=$(cd "$( dirname "$0" )" && pwd)

branch_name=$1

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


cd "$ABSPATH"/../Light-Dedup-J/ || exit
git checkout "$branch_name"
echo "COMMITID: $(git rev-parse HEAD)"
sudo make -j32
sudo bash -c "echo $0 $* > /dev/kmsg"

if [[ "${branch_name}" == *"regulate"* || "${branch_name}" == *"pm-table"* ]]; then
    sudo bash setup.sh "$2" "$3" "$4"
else
    restore_pmem "setup.sh" 
    set_pmem "setup.sh" "pmem0"
    sudo bash setup.sh "$2"
    restore_pmem "setup.sh" 
    git checkout -- "setup.sh"
fi

cd - || exit

#!/usr/bin/env bash

OUTNAME="stdout"

bash ./compile.sh
 
function get_pmem0_id () {
  if ! sudo ipmctl show -performance | grep "DimmID=" | sed -n "1p" | sed 's/---//g' | sed 's/DimmID=//g'; then
    echo "Error: Cannot get pmem0 id. Did you active pmem0?"
    exit 1
  fi
}

# set default pmem id
PMEM_ID=$(get_pmem0_id)

function set_pmem_id() {
  FILE=$1
  PMEM_ID=$2
  sed_cmd=s/PMEM_ID/"$PMEM_ID"/g
  sed -i "$sed_cmd" "$FILE"
}

loop=1
if [ "$1" ]; then
  loop=$1
fi

for filename in `ls`
do
  if test -d "$filename" ; then

    if ( echo "$filename" | grep -q "Deprecated" ); then 
      continue
    fi

    if ( echo "$filename" | grep -q "Finished" ); then 
      continue
    fi

    if ( echo "$filename" | grep -q "TODO" ); then 
      continue
    fi

    if ( echo "$filename" | grep -q "STAT" ); then 
      continue
    fi

    cd "$filename" || exit

    # Set pmem0 id
    if [[ "${filename}" == "TABLE_AgingSystem" ]]; then
      bash test.sh "$PMEM_ID" "$loop" > $OUTNAME
    else    
      bash test.sh "$loop" > $OUTNAME
    fi

    # Aggregate Results
    if [ -f "agg.sh" ]; then
        bash agg.sh "$loop"
    fi

    # Run Process Script
    if [ -f "process.py" ]; then
        python3 process.py
    fi

    cd - || exit
  fi
done

# Draw Figures
bash batch_draw.sh
# Fetch all figures in fig-fetched
bash fetch_all_figures.sh
# Craft latex table
bash batch_craft_table.sh
#!/usr/bin/env bash

loop=1
if [ "$1" ]; then
    loop=$1
fi

bash ./test-all-dram.sh "$loop"
bash ./test-all-pm.sh "$loop"
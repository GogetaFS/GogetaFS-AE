#!/usr/bin/env bash

loop=1
if [ "$1" ]; then
    loop=$1
fi

bash ./test-trace-all-pm.sh "$loop"
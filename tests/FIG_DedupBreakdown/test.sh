#!/usr/bin/env bash

loop=1
if [ "$1" ]; then
    loop=$1
fi

bash ./test-fio.sh "$loop"
bash ./test-real.sh "$loop"
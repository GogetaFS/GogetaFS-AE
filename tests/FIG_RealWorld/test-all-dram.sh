#!/usr/bin/env bash

#!/usr/bin/env bash

loop=1
if [ "$1" ]; then
    loop=$1
fi

bash ./test-cp-all-dram.sh "$loop"
bash ./test-trace-all-dram.sh "$loop"
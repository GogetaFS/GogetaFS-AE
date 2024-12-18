#!/usr/bin/env bash

#!/usr/bin/env bash

loop=1
if [ "$1" ]; then
    loop=$1
fi

bash ./test-4K-hybrid.sh "$loop"
bash ./test-continuous-hybrid.sh "$loop"
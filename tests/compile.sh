#!/usr/bin/env bash

# Compile nvm_tools-J
cd ../nvm_tools-J/ || exit
make -j"$(nproc)"
cd - || exit

# Compile mcp
cd ../mcp/ || exit
rm CMakeCache.txt
cmake CMakeLists.txt
make -j"$(nproc)"
if [ ! -f "/bin/mcp" ]; then
    cp ./mcp /bin/mcp    
fi
cd - || exit

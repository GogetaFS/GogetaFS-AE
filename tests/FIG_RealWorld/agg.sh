#!/usr/bash

loop=1
if [ "$1" ]; then
    loop=$1
fi

table_name="performance-comparison-table-cp-all-dram"

python3 ../aggregate.py "$table_name" "$loop"
mv "$table_name" "$table_name"-orig
mv "$table_name"_agg "$table_name"

table_name="performance-comparison-table-cp-all-pm"

python3 ../aggregate.py "$table_name" "$loop"
mv "$table_name" "$table_name"-orig
mv "$table_name"_agg "$table_name"

table_name="performance-comparison-table-cp-hybrid"

python3 ../aggregate.py "$table_name" "$loop"
mv "$table_name" "$table_name"-orig
mv "$table_name"_agg "$table_name"

table_name="performance-comparison-table-trace-all-dram"

python3 ../aggregate.py "$table_name" "$loop"
mv "$table_name" "$table_name"-orig
mv "$table_name"_agg "$table_name"

table_name="performance-comparison-table-trace-all-pm"

python3 ../aggregate.py "$table_name" "$loop"
mv "$table_name" "$table_name"-orig
mv "$table_name"_agg "$table_name"

table_name="performance-comparison-table-trace-hybrid"

python3 ../aggregate.py "$table_name" "$loop"
mv "$table_name" "$table_name"-orig
mv "$table_name"_agg "$table_name"
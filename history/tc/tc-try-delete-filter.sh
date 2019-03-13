#!/bin/bash

#base="tc -n qrouter-7559b358-6cf4-4900-9c7d-99046bbad2db filter delete dev qg-98a09b15-49"
base="ip netns exec qrouter-7559b358-6cf4-4900-9c7d-99046bbad2db"
cmd_base="$base tc filter delete dev qg-98a09b15-49"
declare -a cmds=(
"parent 1: protocol all prio 1 u32 flowid 1:130"
"parent 1: protocol all prio 1 u32 match ip src 172.16.0.133 flowid 1:130"
"parent 1: protocol all prio 1 u32 match ip src 172.16.0.133 flowid 133"
"protocol all prio 1 u32 match ip src 172.16.0.133 flowid 133"
)
show_filter="$base tc filter show dev qg-98a09b15-49"

function init
{
    if [[ `eval $show_filter` == "" ]]; then
        bash ~/tc-create.sh
    fi
}

function clean
{
    eval "$base tc qdisc delete dev qg-98a09b15-49 root"
}

for cmd in "${cmds[@]}"
do
    init
    eval "${cmd_base} $cmd"
    echo "after run cmd: $cmd_base $cmd"
    eval $show_filter
    clean
    echo ""
done

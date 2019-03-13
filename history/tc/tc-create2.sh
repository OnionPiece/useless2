#!/bin/bash

ns_name=`ip netns identify`
if [[ $ns_name != '' ]]; then
    tc='tc'
else
    tc='ip netns exec qrouter-7559b358-6cf4-4900-9c7d-99046bbad2db tc'
fi
dev='qg-98a09b15-49'
# root qdisc
$tc qdisc add dev $dev root handle 1:0 htb

#
$tc class add dev $dev parent 1: classid 1:172 htb rate 10mbit
$tc qdisc add dev $dev parent 1:172 handle 172: htb

#
$tc class add dev $dev parent 172: classid 172:16 htb rate 10mbit
$tc qdisc add dev $dev parent 1:172 handle 172: htb
$tc filter add dev $dev parent 172: protocol all prio 1 u32 match ip src 172.16.0.133/32 flowid 1:133

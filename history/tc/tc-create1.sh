#!/bin/bash

ns_name=`ip netns identify`
if [[ $ns_name != '' ]]; then
    tc='tc'
    dev=`ip a | awk -F":" '/: qg-/{print $2}'`
else
    ns_name='qrouter-7559b358-6cf4-4900-9c7d-99046bbad2db'
    tc="ip netns exec $ns_name tc"
    dev=`ip netns exec $ns_name ip a | awk -F":" '/: qg-/{print $2}'`
fi
# root qdisc
$tc qdisc add dev $dev root handle 1:0 htb default 1130

### branch fip-1
# class 1:1
$tc class add dev $dev parent 1: classid 1:9999 htb rate 3mbit
# class 1:1 has a sfq leaf
$tc qdisc add dev $dev parent 1:9999 handle 9999: sfq
# add filter for class 1:1
$tc filter add dev $dev parent 1: protocol all prio 1 u32 match ip src 172.16.0.133/32 flowid 1:9999
### end of branch fip-1

### branch qg
# class 1:2
$tc class add dev $dev parent 1: classid 1:130 htb rate 5mbit
# class 1:2 has a sfq leaf
$tc qdisc add dev $dev parent 1:130 handle 1130: sfq
# add filter for class 1:2
$tc filter add dev $dev parent 1: protocol all prio 1 u32 match ip src 172.16.0.130/32 flowid 1:130
### end of branch qg

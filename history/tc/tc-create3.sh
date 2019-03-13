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

### branch 172.0.0.0/8
$tc class add dev $dev parent 1: classid 1:172 htb rate 10mbit
$tc filter add dev $dev parent 1: protocol all prio 1 u32 match ip src 172.0.0.0/8 flowid 1:172

### branch 172.16.0.0/16
$tc class add dev $dev parent 1:172 classid 1:16 htb rate 10mbit
$tc filter add dev $dev parent 1:172 protocol all prio 1 u32 match ip src 172.16.0.0/16 flowid 1:16
### branch 172.0.0.0/16
$tc class add dev $dev parent 1:172 classid 1:256 htb rate 10mbit
$tc filter add dev $dev parent 1:172 protocol all prio 1 u32 match ip src 172.0.0.0/16 flowid 1:256

### branch 172.16.0.0/24
$tc class add dev $dev parent 1:16 classid 1:256 htb rate 10mbit
$tc filter add dev $dev parent 1:16 protocol all prio 1 u32 match ip src 172.16.0.0/24 flowid 1:256
### branch 172.0.16.0/24
$tc class add dev $dev parent 1:256 classid 1:16 htb rate 10mbit
$tc filter add dev $dev parent 1:256 protocol all prio 1 u32 match ip src 172.0.16.0/24 flowid 1:16

### branch fip-1
# class 1:1
$tc class add dev $dev parent 1:256 classid 1:133 htb rate 3mbit
# class 1:1 has a sfq leaf
$tc qdisc add dev $dev parent 1:133 handle 133: sfq
# add filter for class 1:1
$tc filter add dev $dev parent 1:256 protocol all prio 1 u32 match ip src 172.16.0.133/32 flowid 1:133
### end of branch fip-1

$tc class add dev $dev parent 1:16 classid 1:133 htb rate 3mbit
$tc qdisc add dev $dev parent 1:133 handle 133: sfq
$tc filter add dev $dev parent 1:256 protocol all prio 1 u32 match ip src 172.16.0.133/32 flowid 1:133

### branch qg
# class 1:2
$tc class add dev $dev parent 1: classid 1:130 htb rate 5mbit
# class 1:2 has a sfq leaf
$tc qdisc add dev $dev parent 1:130 handle 1130: sfq
# add filter for class 1:2
$tc filter add dev $dev parent 1: protocol all prio 1 u32 match ip src 172.16.0.130/32 flowid 1:130
### end of branch qg

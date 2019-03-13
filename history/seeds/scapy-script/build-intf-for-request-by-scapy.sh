#!/bin/bash

if test -z $1; then
    echo "need assign tap device to mock."
    ip l | grep tap | cut -d ':' -f 2
    exit 1
fi
tap=$1
sudo ovs-ofctl show br-int | grep -q qvo-ppp
if [[ $? -ne 0 ]]; then
    sudo ip link add ppp type veth peer name qvo-ppp
    sudo ip link set ppp up
    sudo ip link set ppp promisc on
    sudo ovs-vsctl add-port br-int qvo-ppp
    sudo ip link set qvo-ppp up
fi

tap_in_port=`sudo ovs-ofctl show br-int | grep ${tap} | cut -d ' ' -f 2 | cut -d '(' -f 1`
in_port=`sudo ovs-ofctl show br-int | grep "qvo-ppp" | cut -d ' ' -f 2 | cut -d '(' -f 1`
actions=`sudo ovs-ofctl dump-flows br-int table=0 | grep "in_port=${tap_in_port}" | awk '{print $8}'`
sudo ovs-ofctl add-flow br-int "table=0,priority=100,in_port=${in_port},${actions}"

#!/bin/bash

# VM reboot will cause tap device rebuild in OVN env.
# By that in_port in ovs flow table 0 will be updated.
# Always run this after VM reboot a while.
# tcpdump can tell whether the new tap device is created completed.

if test -z $1; then
    echo "need to assign a tap device."
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
sudo ovs-ofctl add-flow br-int "table=0,priority=200,in_port=${in_port},actions=output:${tap_in_port}"

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
fake_in_port=`sudo ovs-ofctl show br-int | grep "qvo-ppp" | cut -d ' ' -f 2 | cut -d '(' -f 1`

vm_mac=`mysql -uroot -ppassword "neutron" -e "select * from ports" | grep ${tap:3:11} | awk '{print $4}'`
vm_ip=`mysql -uroot -ppassword "neutron" -e "select * from ipallocations" | grep ${tap:3:11} | sort | awk '/\./{print $2}'`
echo "VM IP: " $vm_ip
fake_mac=`ip l show ppp | awk '/ether/ {print $2}'`
#fake_ip="10.0.0.234/24"
fake_ip=`echo $vm_ip | cut -d '.' -f 1-3`.234
echo "fake IP: " $fake_ip

sudo ip a replace dev ppp $fake_ip
sudo ovs-ofctl add-flow br-int "table=0,priority=100,in_port=${fake_in_port},actions=output:$tap_in_port"
sudo ovs-ofctl add-flow br-int "table=0,priority=110,arp,arp_tpa=$fake_ip,arp_op=1,actions=output:$fake_in_port"
sudo ovs-ofctl add-flow br-int "table=0,priority=110,in_port=${tap_in_port},dl_dst=$fake_mac,actions=output:$fake_in_port"
sudo ip n replace $vm_ip dev ppp lladdr $vm_mac
sudo ip r replace ${fake_ip::-3}0/24 dev ppp

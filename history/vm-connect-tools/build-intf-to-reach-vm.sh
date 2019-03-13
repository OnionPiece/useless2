#!/bin/bash

base_mac="fa:16:3e"
modify_ipset="True"
ping_retry_count=2

if test -z $1; then
    echo "need assign tap device to mock."
    ip l | awk -F ':' '/ tap/{print $2}'
    exit 1
fi

tap_dev=$1
ofp_dev=`sudo ovs-vsctl list-ports br-int | grep ${tap_dev:3:-1}`
ofport=`sudo ovs-vsctl get interface $ofp_dev ofport`
vm_mac=`ip l show $tap_dev | awk '/ether /{print $2}' | cut -d ':' -f 4-6 | xargs -I {} echo "${base_mac}:{}"`

ppp_dev="ppp-ssh"
sudo ovs-vsctl -- --may-exist add-port br-int $ppp_dev -- set interface $ppp_dev type=internal
sudo ip l set $ppp_dev up
sudo sysctl net.ipv6.conf.${ppp_dev}.disable_ipv6=0
ppp_ofport=`sudo ovs-vsctl get interface $ppp_dev ofport`
ppp_mac=`sudo ovs-vsctl get interface $ppp_dev mac_in_use | cut -c 2-18`

# calculate IPv6 LLA for VM
function get_lla()
{
    p1=`echo $1 | cut -d ':' -f 1 | xargs -I {} echo "0x"{}`
    p2=`echo $1 | cut -d ':' -f 2-3`
    p3=`echo $1 | cut -d ':' -f 4-5`
    p4=`echo $1 | cut -d ':' -f 6`
    p1=$((p1 ^ 2))
    p1=`printf "%x" $p1`
    echo "fe80::${p1}${p2}ff:fe${p3}${p4}"
}

vm_lla=`get_lla $vm_mac`
echo "VM lla: $vm_lla"
ppp_lla=`get_lla $ppp_mac`

sudo ovs-ofctl add-flow br-int "table=0,priority=233,icmp6,icmp_type=135,dl_src=${ppp_mac},ipv6_src=${ppp_lla},nd_target=${vm_lla},in_port=${ppp_ofport},actions=output:${ofport}"
sudo ovs-ofctl add-flow br-int "table=0,priority=233,ipv6,dl_src=${ppp_mac},ipv6_src=${ppp_lla},ipv6_dst=${vm_lla},in_port=${ppp_ofport},actions=output:${ofport}"
sudo ovs-ofctl add-flow br-int "table=0,priority=233,ipv6,dl_src=${vm_mac},ipv6_src=${vm_lla},ipv6_dst=${ppp_lla},in_port=${ofport},actions=output:${ppp_ofport}"
echo "waiting ovs flow installation..."
sleep 2

echo "starting ping test..."
ping6 $vm_lla -I $ppp_dev -c3 -w3 > /dev/null
if [[ $? -ne 0 ]];then
    ping_pass=0
    if [[ $modify_ipset == "true" || $modify_ipset == "True" ]];then
        echo "ping6 test failed, try to modify ipset..."
        ip_set=`ip6tables -S neutron-openvswi-i${tap_dev:3:-1} | awk '/--match-set/{print $6}'`
        ipset add $ip_set $ppp_lla
        for((i=0;i!=$ping_retry_count;i++)); do
            sleep 2
            ping6 $vm_lla -I $ppp_dev -c3 -w3 > /dev/null
            if [[ $? -eq 0 ]];then
                ping_pass=1
                break
            fi
        done
        if [[ $ping_pass -ne 0 ]];then
            ipset del $ip_set $ppp_lla
            echo "fail to ping6 VM LLA..."
            echo "run clean-intf-to-reach-vm-v2.sh to cleanup..."
            exit 1
        fi
    else
        echo "ping6 test failed, try to modify ip6tables..."
        ip6tables -I neutron-openvswi-i${tap_dev:3:-1} 1 -p ipv6-icmp -m comment --comment "build-intf-to-reach-vm:allow icmpv6 ping request" --icmpv6-type 128 -j RETURN
        for((i=0;i!=$ping_retry_count;i++)); do
            sleep 2
            ping6 $vm_lla -I $ppp_dev -c3 -w3 > /dev/null
            if [[ $? -eq 0 ]];then
                ping_pass=1
                break
            fi
        done
        if [[ $ping_pass -ne 0 ]];then
            ip6tables -D neutron-openvswi-i${tap_dev:3:-1} 1
            echo "fail to ping6 VM LLA..."
            echo "run clean-intf-to-reach-vm-v2.sh to cleanup..."
            exit 1
        fi

        ip6tables -I neutron-openvswi-i${tap_dev:3:-1} 1 -p tcp --dport 22 -m comment --comment "build-intf-to-reach-vm:allow tcp 22" -j RETURN
    fi
fi

echo "try something like:"
echo "ping6 ${vm_lla} -I $ppp_dev"
echo "ssh cirros@${vm_lla}%$ppp_dev"

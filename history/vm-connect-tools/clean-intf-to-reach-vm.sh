#!/bin/bash

ppp_dev="ppp-ssh"
ppp_mac=`ip l show $ppp_dev | awk '/ether / {print $2}'`
ppp_ofport=`sudo ovs-vsctl get interface $ppp_dev ofport`

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

ppp_lla=`get_lla $ppp_mac`

sudo ovs-ofctl del-flows br-int "table=0,ipv6,dl_src=${ppp_mac},in_port=${ppp_ofport}"
sudo ovs-ofctl del-flows br-int "table=0,ipv6,ipv6_dst=${ppp_lla}"
sudo ovs-vsctl --if-exist del-port br-int $ppp_dev

for chain in `ip6tables -S | awk '/build-intf-to-reach-vm/{print $2}' | uniq`
do
    for rule in `ip6tables -L $chain | awk '/build-intf-to-reach-vm/{print NR-2}' | sort -r`
    do
        ip6tables -D $chain $rule
    done
done
for nset in `ipset -n list`
do
    ipset -q del $nset $ppp_lla
done

echo "cleanup verify (should output nothing):"
echo "ovs-ofctl dump-flows check: "`sudo ovs-ofctl dump-flows br-int table=0 | grep "priority=233"`
echo "ip l check: "`ip l | grep $ppp_dev`
echo "ip6tables -S check: "`ip6tables -S | grep "build-intf-to-reach-vm"`
echo "ipset list check: "`ipset list | grep $ppp_lla`

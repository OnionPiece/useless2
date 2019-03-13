#!/bin/bash

ovs-ofctl del-flows br-ex

pc_ofp=`ovs-vsctl get interface 2ctrl ofport`
ctrl_ip="172.16.0.254"
pc_tos=0x40

host_id=`hostname | cut -c 4`
local_tos=$((host_id << 4))
local_ip=`ip a show br-ex | awk '/ inet /{print $2}'`
local_mac=`ip l show br-ex | awk '/ link\/ether /{print $2}'`
ports=`ovs-vsctl list-ports br-ex | grep 2net`
port1=`echo $ports | cut -d ' ' -f 1`
port2=`echo $ports | cut -d ' ' -f 2`
p1_ofp=`ovs-vsctl get interface $port1 ofport`
p2_ofp=`ovs-vsctl get interface $port2 ofport`
p1_id=`echo $port1 | cut -c 5`
p2_id=`echo $port2 | cut -c 5`
p1_tos=$((p1_id << 4))
p2_tos=$((p2_id << 4))

flow_file=/tmp/br-ex-flows
rm -rf $flow_file

flows="""
#inport_triage
table=0,priority=10,ipv6,actions=drop
table=0,priority=10,in_port=$p1_ofp,ipv4,nw_tos=$p2_tos,actions=drop
table=0,priority=10,in_port=$p1_ofp,ipv4,nw_tos=$pc_tos,actions=drop
table=0,priority=10,in_port=$p1_ofp,arp,arp_spa=${ctrl_ip},actions=drop
table=0,priority=10,in_port=$p2_ofp,ipv4,nw_tos=$p1_tos,actions=drop
table=0,priority=10,in_port=$p2_ofp,ipv4,nw_tos=$pc_tos,actions=drop
table=0,priority=10,in_port=$p2_ofp,arp,arp_spa=${ctrl_ip},actions=drop
table=0,priority=10,in_port=$pc_ofp,ipv4,nw_tos=$p1_tos,actions=drop
table=0,priority=10,in_port=$pc_ofp,ipv4,nw_tos=$p2_tos,actions=drop
table=0,priority=10,in_port=$p1_ofp,arp,arp_op=2,actions=drop
table=0,priority=10,in_port=$p2_ofp,arp,arp_op=2,actions=drop
table=0,priority=2,in_port=$p1_ofp,actions=resubmit(,1)
table=0,priority=2,in_port=$p2_ofp,actions=resubmit(,1)
table=0,priority=2,in_port=$pc_ofp,actions=resubmit(,1)
table=0,priority=2,in_port=local,actions=resubmit(,1)
table=0,priority=1,actions=resubmit(,2)

#ingress_traffic
table=1,priority=10,in_port=$pc_ofp,arp,arp_op=2,actions=flood
table=1,priority=10,ipv4,in_port=$p1_ofp,nw_tos=$p1_tos,actions=NORMAL
table=1,priority=10,ipv4,in_port=$p2_ofp,nw_tos=$p2_tos,actions=NORMAL
table=1,priority=10,ipv4,in_port=$pc_ofp,nw_tos=$pc_tos,actions=flood
table=1,priority=2,in_port=local,actions=flood
table=1,priority=1,actions=drop

#egress_traffic
table=2,priority=10,ipv4,nw_dst=${ctrl_ip},actions=mod_nw_tos:$local_tos,output:$pc_ofp
table=2,priority=9,ipv4,nw_tos=0,actions=mod_nw_tos:$local_tos,flood
table=2,priority=9,ipv4,nw_tos=$p1_tos,actions=mod_nw_tos:$local_tos,output:$p1_ofp
table=2,priority=9,ipv4,nw_tos=$p2_tos,actions=mod_nw_tos:$local_tos,output:$p2_ofp
table=2,priority=8,ipv4,nw_dst=$local_ip,actions=LOCAL
table=2,priority=8,arp,dl_dst=$local_mac,actions=LOCAL
table=2,priority=8,arp,arp_op=1,arp_tpa=$local_ip,actions=LOCAL
table=2,priority=2,arp,arp_op=1,actions=output:$pc_ofp
table=2,priority=1,actions=drop
"""

for flow in $flows
do
    echo $flow >> $flow_file
done

ovs-ofctl add-flows br-ex $flow_file

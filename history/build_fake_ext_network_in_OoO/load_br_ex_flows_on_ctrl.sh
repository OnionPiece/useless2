#!/bin/bash

ovs-ofctl del-flows br-ex

local_tos=0x40
p1_tos=0x10
p2_tos=0x20
p3_tos=0x30
p1_ofp=`ovs-vsctl get interface 2net1 ofport`
p2_ofp=`ovs-vsctl get interface 2net2 ofport`
p3_ofp=`ovs-vsctl get interface 2net3 ofport`
pc_ofp=`ovs-vsctl get interface pppex ofport`
local_ip="172.16.0.254"

flow_file=./br-ex-flows
rm -rf $flow_file

flows="""
#inport_triage
table=0,priority=10,ipv6,actions=drop
table=0,priority=10,in_port=$p1_ofp,ipv4,nw_tos=$p1_tos,actions=resubmit(,1)
table=0,priority=10,in_port=$p1_ofp,ipv4,nw_tos=$p2_tos,actions=drop
table=0,priority=10,in_port=$p1_ofp,ipv4,nw_tos=$p3_tos,actions=drop
table=0,priority=10,in_port=$p2_ofp,ipv4,nw_tos=$p2_tos,actions=resubmit(,1)
table=0,priority=10,in_port=$p2_ofp,ipv4,nw_tos=$p1_tos,actions=drop
table=0,priority=10,in_port=$p2_ofp,ipv4,nw_tos=$p3_tos,actions=drop
table=0,priority=10,in_port=$p3_ofp,ipv4,nw_tos=$p3_tos,actions=resubmit(,1)
table=0,priority=10,in_port=$p3_ofp,ipv4,nw_tos=$p1_tos,actions=drop
table=0,priority=10,in_port=$p3_ofp,ipv4,nw_tos=$p2_tos,actions=drop
table=0,priority=9,in_port=$p1_ofp,arp,actions=resubmit(,1)
table=0,priority=9,in_port=$p2_ofp,arp,actions=resubmit(,1)
table=0,priority=9,in_port=$p3_ofp,arp,actions=resubmit(,1)
table=0,priority=1,in_port=$pc_ofp,actions=resubmit(,2)

#ingress_traffic
table=1,priority=10,ipv4,nw_dst=$local_ip,actions=output:$pc_ofp
table=1,priority=9,arp,arp_op=2,actions=output:$pc_ofp
table=1,priority=1,arp,actions=resubmit(,16)

#egress_traffic
table=2,priority=10,ipv4,nw_tos=0,actions=mod_nw_tos:$local_tos,FLOOD
table=2,priority=10,ipv4,nw_tos=0x10,actions=mod_nw_tos:$local_tos,output:$p1_ofp
table=2,priority=10,ipv4,nw_tos=0x20,actions=mod_nw_tos:$local_tos,output:$p2_ofp
table=2,priority=10,ipv4,nw_tos=0x30,actions=mod_nw_tos:$local_tos,output:$p3_ofp
table=2,priority=1,arp,arp_op=1,actions=resubmit(,16)

#arp_responder
table=16,priority=0,actions=drop
"""

for flow in $flows
do
    echo $flow >> $flow_file
done

ovs-ofctl add-flows br-ex $flow_file

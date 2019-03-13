#!/bin/bash

ovs-ofctl del-flows br-node-ex

px_ip=`ip a show br-node-ex | awk '/ inet /{print $2}' | cut -d '/' -f 1`
px_tos=0x40
p1_tos=0x10
p2_tos=0x20
p3_tos=0x30
p1_ofp=`ovs-vsctl get interface 2net1 ofport`
p2_ofp=`ovs-vsctl get interface 2net2 ofport`
p3_ofp=`ovs-vsctl get interface 2net3 ofport`

flow_file=./br-node-ex-flows
rm -rf $flow_file

flows="""
#inport_triage
table=0,priority=10,ipv6,actions=drop

table=0,priority=9,in_port=$p1_ofp,ipv4,nw_tos=$p1_tos,actions=resubmit(,1)
#table=0,priority=9,in_port=$p1_ofp,ipv4,nw_tos=$p2_tos,actions=drop
#table=0,priority=9,in_port=$p1_ofp,ipv4,nw_tos=$p3_tos,actions=drop
#table=0,priority=9,in_port=$p2_ofp,ipv4,nw_tos=$p1_tos,actions=drop
table=0,priority=9,in_port=$p2_ofp,ipv4,nw_tos=$p2_tos,actions=resubmit(,1)
#table=0,priority=9,in_port=$p2_ofp,ipv4,nw_tos=$p3_tos,actions=drop
#table=0,priority=9,in_port=$p3_ofp,ipv4,nw_tos=$p1_tos,actions=drop
#table=0,priority=9,in_port=$p3_ofp,ipv4,nw_tos=$p2_tos,actions=drop
table=0,priority=9,in_port=$p3_ofp,ipv4,nw_tos=$p3_tos,actions=resubmit(,1)

table=0,priority=8,arp,in_port=$p1_ofp,actions=resubmit(,1)
table=0,priority=8,arp,in_port=$p2_ofp,actions=resubmit(,1)
table=0,priority=8,arp,in_port=$p3_ofp,actions=resubmit(,1)

table=0,priority=7,in_port=local,actions=resubmit(,2)

table=0,priority=1,actions=drop


#ingress
table=1,priority=1,actions=LOCAL


#egress
table=2,priority=2,ipv4,actions=mod_nw_tos:$px_tos,output:$p1_ofp,output:$p2_ofp,output:$p3_ofp
table=2,priority=1,arp,actions=output:$p1_ofp,output:$p2_ofp,output:$p3_ofp
"""

for flow in $flows
do
    echo $flow >> $flow_file
done

ovs-ofctl add-flows br-node-ex $flow_file

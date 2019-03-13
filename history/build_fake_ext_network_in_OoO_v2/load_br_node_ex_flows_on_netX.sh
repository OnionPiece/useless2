#!/bin/bash

ovs-ofctl del-flows br-node-ex

pc_ofp=`ovs-vsctl get interface 2ctrl ofport`
pc_tos=0x40
pc_ip=`ovs-vsctl get interface 2ctrl options | cut -d '"' -f 6`

host_id=`hostname | cut -c 4`
px_tos=$((host_id << 4))
px_ip=`ip a show br-node-ex | awk '/ inet /{print $2}' | cut -d '/' -f 1`
ports=`ovs-vsctl list-ports br-node-ex | grep 2net`
port1=`echo $ports | cut -d ' ' -f 1`
port2=`echo $ports | cut -d ' ' -f 2`
p1_ofp=`ovs-vsctl get interface $port1 ofport`
p2_ofp=`ovs-vsctl get interface $port2 ofport`
p1_id=`echo $port1 | cut -c 5`
p2_id=`echo $port2 | cut -c 5`
p1_tos=$((p1_id << 4))
p2_tos=$((p2_id << 4))
p1_ip=`ovs-vsctl get interface $port1 options | cut -d '"' -f 6`
p2_ip=`ovs-vsctl get interface $port2 options | cut -d '"' -f 6`

ingress_ofp=`ovs-vsctl get interface 2-br-ex ofport`

flow_file=/tmp/br-node-ex-flows
rm -rf $flow_file

flows="""
#inport_triage
table=0,priority=10,ipv6,actions=drop

#table=0,priority=9,in_port=$p1_ofp,ipv4,nw_tos=$p2_tos,actions=drop
#table=0,priority=9,in_port=$p1_ofp,ipv4,nw_tos=$pc_tos,actions=drop
#table=0,priority=9,in_port=$p1_ofp,ipv4,nw_tos=$px_tos,actions=drop
#table=0,priority=9,in_port=$p2_ofp,ipv4,nw_tos=$p1_tos,actions=drop
#table=0,priority=9,in_port=$p2_ofp,ipv4,nw_tos=$pc_tos,actions=drop
#table=0,priority=9,in_port=$p2_ofp,ipv4,nw_tos=$px_tos,actions=drop
#table=0,priority=9,in_port=$pc_ofp,ipv4,nw_tos=$p1_tos,actions=drop
#table=0,priority=9,in_port=$pc_ofp,ipv4,nw_tos=$p2_tos,actions=drop
#table=0,priority=9,in_port=$pc_ofp,ipv4,nw_tos=$px_tos,actions=drop

table=0,priority=2,in_port=$p1_ofp,actions=resubmit(,1)
table=0,priority=2,in_port=$p2_ofp,actions=resubmit(,1)
table=0,priority=2,in_port=$pc_ofp,actions=resubmit(,1)
table=0,priority=2,in_port=local,actions=resubmit(,1),resubmit(,2)
table=0,priority=1,actions=resubmit(,2)


#ingress_traffic
table=1,priority=2,in_port=local,actions=output:$ingress_ofp
table=1,priority=1,actions=output:$ingress_ofp,LOCAL


#egress_traffic
table=2,priority=10,ipv4,nw_tos=0,nw_dst=$px_ip,actions=mod_nw_tos:$px_tos,LOCAL
table=2,priority=10,ipv4,nw_tos=0,nw_dst=$p1_ip,actions=mod_nw_tos:$px_tos,output:$p1_ofp
table=2,priority=10,ipv4,nw_tos=0,nw_dst=$p2_ip,actions=mod_nw_tos:$px_tos,output:$p2_ofp
table=2,priority=10,ipv4,nw_tos=0,nw_dst=$pc_ip,actions=mod_nw_tos:$px_tos,output:$pc_ofp

table=2,priority=9,ipv4,nw_tos=0,actions=mod_nw_tos:$px_tos,output:$p1_ofp,output:$p2_ofp

table=2,priority=8,ipv4,nw_tos=$p1_tos,actions=mod_nw_tos:$px_tos,output:$p1_ofp
table=2,priority=8,ipv4,nw_tos=$p2_tos,actions=mod_nw_tos:$px_tos,output:$p2_ofp
table=2,priority=8,ipv4,nw_tos=$pc_tos,actions=mod_nw_tos:$px_tos,output:$pc_ofp

table=2,priority=7,arp,in_port=$ingress_ofp,arp_tpa=$px_ip,actions=LOCAL
table=2,priority=7,arp,in_port=$ingress_ofp,arp_tpa=$p1_ip,actions=output:$p1_ofp
table=2,priority=7,arp,in_port=$ingress_ofp,arp_tpa=$p2_ip,actions=output:$p2_ofp
table=2,priority=7,arp,in_port=$ingress_ofp,arp_tpa=$pc_ip,actions=output:$pc_ofp

table=2,priority=6,arp,in_port=$ingress_ofp,actions=output:$p1_ofp,output:$p2_ofp

table=2,priority=5,arp,in_port=LOCAL,actions=output:$p1_ofp,output:$p2_ofp,output:$ingress_ofp

table=2,priority=1,actions=drop
"""

for flow in $flows
do
    echo $flow >> $flow_file
done

ovs-ofctl add-flows br-node-ex $flow_file

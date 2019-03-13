#!/bin/bash
# writen by zongkai@polex.com.cn

function usage
{
    echo "usage: bash $0 IP MAC [BRIDGE [TABLE [PRIORITY]]]"
    echo "default: br-ex, table=0, priority=1"
    echo "BRIDGE: br-ex/br-int/br-tun/br-vlan/br-vlan1"
    echo "TABLE: [0, 64]"
    echo "PRIORITY: [0, 200]"
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
elif [[ `ipcalc -c $1 >> /dev/null` -ne 0 ]]; then
    usage
elif [[ `echo $2 | egrep "^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$"` == "" ]]; then
    usage
elif [[ $3 != "" && `echo "br-ex|br-tun|br-int|br-vlan|br-vlan1" | egrep $3` == "" ]] ; then
    usage
elif [[ $4 != "" && $4 -lt 0 || $4 -gt 64 ]]; then
    usage
elif [[ $5 != "" && $5 -lt 0 || $5 -gt 200 ]]; then
    usage
fi

ip=$1
mac=$2
ip_p1=`echo $ip | cut -d '.' -f 1`
ip_p2=`echo $ip | cut -d '.' -f 2`
ip_p3=`echo $ip | cut -d '.' -f 3`
ip_p4=`echo $ip | cut -d '.' -f 4`
ip_hex=`printf "%02x%02x%02x%02x" "$ip_p1" "$ip_p2" "$ip_p3" "$ip_p4"`
mac_hex=`echo ${mac//:/}`

MATCH="""
arp,arp_tpa=$ip,arp_op=1
"""
ARP_RESPONDER_ACTIONS="""
move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],
mod_dl_src:$mac,
load:0x2->NXM_OF_ARP_OP[],
move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],
move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],
load:0x$mac_hex->NXM_NX_ARP_SHA[],
load:0x$ip_hex->NXM_OF_ARP_SPA[],
in_port
"""
ovs-ofctl add-flow $3 "table=$4,priority=$5,$MATCH,actions=$ARP_RESPONDER_ACTIONS"

#!/bin/bash
# writen by zongkai@polex.com.cn
# R2I means: Router(router netns or fip) 2 Instance.
# error code: 1, wrong parameters
#             2, not active vrouter hosting
#             3, ping check fail on halfway

SRC_IP=`ip a show br-ex | awk '/ inet /{print $2}' | cut -d '/' -f 1`
OPENRC=/root/openrc
source $OPENRC

function usage
{
    echo "Usage: $0 instance INSTANCE_ID or INSTANCE_UNIQUE_NAME"
    echo "Usage: $0 port PORT_ID or PORT_UNIQUE_NAME"
    exit 1
}

function goto_exit
{
    rm -rf $ping_pid_file
    rm -rf $sg_rules_file
    #rm -rf $tmp_file
    kill -9 $ping_pid 1>/dev/null 2>/dev/null
    exit $1
}

# traffic_dump DIRECTION DEVICE DEVICE_DIRECTION
function traffic_dump
{
    echo "Start to dump $1 traffic in router namespace qrouter-${router_id} on $2"
    timeout 3 ip netns exec qrouter-${router_id} tcpdump -i $2 host $SRC_IP -P $3 -c 1 > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Tcpdump: $1 traffic pass router namespace qrouter-${router_id} $2 ... FAIL"
        if [[ $1 == "ingress" ]]; then
            goto_exit 3
        fi
    else
        echo "Tcpdump: $1 traffic pass router namespace qrouter-${router_id} $2 ... PASS"
    fi
}

# check_iptables_nat_rules NAT_TYPE IP_2_CHECK
function check_iptables_nat_rules
{
    if [[ $1 == "dnat" ]]; then
        chain="neutron-vpn-agen-OUTPUT"
        direction="destination"
    else
        chain="neutron-vpn-agen-float-snat"
        direction="source"
    fi
    nat_rule=`ip netns exec qrouter-$router_id iptables -t nat -S $chain | grep "$2"`
    echo "Found NAT($1) rule $nat_rule"
    nat_ip=`echo $nat_rule | awk '{print $8}'`
    if [[ $nat_ip != $2 ]]; then
        echo "The $direction ip $nat_ip in $1 rule doesn't match port ip $2!"
        goto_exit 3
    fi
    echo "Iptables rules supply for floatingip in $1 ... PASS"
}

if [[ $# -ne 2 ]]; then
    usage
fi

if [[ $1 == "instance" ]]; then
    if [[ `nova list | grep $2 | wc -l` -ne 1 ]]; then
        echo "The parameter for instance is neither an ID nor name of instance"
        usage
    fi
elif [[ $1 == "port" ]]; then
    if [[ `neutron port-list | grep $2 | wc -l` -ne 1 ]]; then
        echo "The parameter for port is neither an ID nor name of port"
        usage
    fi
else
    usage
fi

TID=`date +%s`
tmp_file=/tmp/$TID
ping_pid_file=/tmp/${TID}.pid-ping
sg_rules_file=/tmp/${TID}.sgrs
path="$(cd `dirname $0`; pwd)"

echo "Start to get port backgrounds"
sleep 1
bash ${path%/*}/describers/describe_port_background.sh $1 $2 > $tmp_file
echo "End of get port backgroupds"

sg_rules_start_line=`cat $tmp_file | grep -n "^Security group rules" | cut -d ':' -f 1`
sg_rules_end_line=`cat $tmp_file | grep -n "^End of security group rules" | cut -d ':' -f 1`
sg_rules_start_line=$((sg_rules_start_line + 1))
sg_rules_end_line=$((sg_rules_end_line - 1))
cat $tmp_file | sed -n "$sg_rules_start_line,${sg_rules_end_line}p" >> $sg_rules_file
egrep -q "ingress.* icmp" $sg_rules_file
if [[ $? -ne 0 ]]; then
    echo "WARNING: no icmp ingress rules found in security group."
fi

active_host=`cat $tmp_file | grep l3-agent-list-hosting-router -A 7 | awk '/:-).*active/{print $4}'`
if [[ $active_host != `hostname` ]]; then
    echo "L3 HA active vRouter on this node is standby. Exit here."
    echo "The active one is on $active_host"
    exit 2
fi

port_id=`cat $tmp_file | awk '/^port_id/{print $2}'`
port_mac=`cat $tmp_file | awk '/^mac_address/{print $2}'`
port_fixed_ip=`cat $tmp_file | awk '/^ip_address/{print $2}'`
router_id=`cat $tmp_file | awk '/^router_id/{print $2}'`
port_fip_ip=`cat $tmp_file | awk '/^floatingip/{print $2}'`

if [[ $port_fip_ip == "" ]]; then
    echo "The $1 $2 has no floatingip associated with, try to ping it from a qrouter-$router_id namespace."
    nohup ip netns exec qrouter-$router_id ping $port_fixed_ip >> /dev/null 2>&1 & echo $! > $ping_pid_file
    ping_pid=`cat $ping_pid_file`
    echo "Ping pid is $ping_pid"
    echo "Router namespace is qrouter-${router_id}"
else
    echo "The $1 $2 has a floatingip associated with, try to ping it directly via floatingip $port_fip_ip from br-ex."
    nohup ping -I br-ex $port_fip_ip >> /dev/null 2>&1 & echo $! > $ping_pid_file
    ping_pid=`cat $ping_pid_file`
    echo "Ping pid is $ping_pid"
    echo "Router namespace is qrouter-${router_id}"

    qg_dev=`ip netns exec qrouter-${router_id} ip l | awk '/: qg-/{print $2}' | cut -d ':' -f 1`
    traffic_dump "ingress" $qg_dev "in"
    traffic_dump "egress" $qg_dev "out"

    check_iptables_nat_rules "dnat" $port_fixed_ip
    check_iptables_nat_rules "snat" $port_fip_ip
fi

qr_dev=`cat $tmp_file | grep "^router interface" -A 5 | awk '/subnet_id/{print $2}'`
qr_dev="qr-"${qr_dev:0:11}
traffic_dump "ingress" $qr_dev "out"
traffic_dump "egress" $qr_dev "in"

dl_vlan=`ovs-vsctl get port $qr_dev tag`
tun_t20_flow_1=`ovs-ofctl dump-flows br-tun "table=20,dl_vlan=$dl_vlan,dl_dst=$port_mac"`
tun_t20_flow_1=`ovs-ofctl dump-flows br-tun "table=20,dl_vlan=$dl_vlan,dl_dst=$port_mac"`
echo "Found ovs tun table 20 (unicast) flow:"
echo "$tun_t20_flow_1"
sleep 2
echo "(2 seconds sleep)"
tun_t20_flow_2=`ovs-ofctl dump-flows br-tun "table=20,dl_vlan=$dl_vlan,dl_dst=$port_mac"`
echo "$tun_t20_flow_2"
n_packets_1=`echo $tun_t20_flow_1 |  awk -F',' '{print $4}'`
n_packets_2=`echo $tun_t20_flow_2 |  awk -F',' '{print $4}'`
if [[ $n_packets_1 == $n_packets_2 ]]; then
    echo "No packets pass tun table 20 flow"
    goto_exit 3
else
    echo "Packets passed tun table 20 flow"
fi
echo "All checking on network node passed!"

goto_exit 0

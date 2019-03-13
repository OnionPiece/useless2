#!/bin/bash
# writen by zongkai@polex.com.cn

OPENRC=/root/openrc
source $OPENRC

function usage
{
    echo "Usage: $0 instance INSTANCE_ID or INSTANCE_UNIQUE_NAME"
    echo "Usage: $0 port PORT_ID or PORT_UNIQUE_NAME"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
fi

if [[ $1 == "instance" ]]; then
    nova show $2 >> /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "If you're using instance name, it may match no or more than one instance, can't handle that case."
        usage
    fi
    port_id=`nova list | grep $2 | awk '{print $2}' | xargs -I {} neutron port-list --device_id={} | awk '{if(NR==4)print $2}'`
elif [[ $1 == "port" ]]; then
    neutron port-show $2 >> /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "If you're using port name, it may match no or more than one port, can't handle that case."
        usage
    fi
    port_id=`neutron port-list | grep $2 | awk '{print $2}'`
else
    usage
fi

TID=`date +%s`

echo "This script will only work for single security-group case."

neutron port-show $port_id > /tmp/$TID
network_id=`awk '/network_id/{print $4}' /tmp/$TID`
subnet_id=`awk -F'"' '/fixed_ips/{print $4}' /tmp/$TID`
ip_address=`awk -F'"' '/fixed_ips/{print $8}' /tmp/$TID`
binding_host=`awk '/host_id/{print $4}' /tmp/$TID`
mac_address=`awk '/mac_address/{print $4}' /tmp/$TID`
security_group=`awk '/security_groups/{print $4}' /tmp/$TID`
fip_address=`neutron floatingip-list --port_id=$port_id | awk '{if(NR==4)print $6}'`
printf "port_id:\t\t$port_id\n"
printf "binding_host:\t\t$binding_host\n"
printf "ip_address:\t\t$ip_address\n"
printf "mac_address:\t\t$mac_address\n"
printf "network_id:\t\t$network_id\n"
printf "subnet_id:\t\t$subnet_id\n"
printf "floatingip:\t\t$fip_address\n"

echo "Security group rules:"
neutron security-group-rule-list --security_group_id=$security_group
echo "End of security group rules."

echo "router interface:"
router_interface=`neutron port-list --fixed_ips subnet_id=$subnet_id --device_owner=network:router_interface`
router_interface_id=`echo $router_interface | awk -F'|' '{print $7}'`
router_id=`neutron port-show $router_interface_id | awk '/device_id/{print $4}'`
echo "$router_interface"

echo "router:"
echo "router_id:	$router_id"
neutron router-show $router_id

echo "l3-agent-list-hosting-router:"
router_bindings=`neutron l3-agent-list-hosting-router $router_id`
echo "$router_bindings"
if [[ `echo "$router_bindings" | wc -l` -ne 7 ]]; then
    echo "+--------------------------------------+------+----------------+-------+----------+"
fi

rm -rf /tmp/$TID

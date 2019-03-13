#!/bin/bash

if test -z $1; then
    echo "need fip-id as parameter"
    exit 1
fi

source ~/openrc
if test "`neutron floatingip-show $1 | awk '/ id /{print $4}'`" != $1; then
    echo "need fip-id as parameter"
    exit 1
fi

IPC_IP_CIDR=172.16.0.12/32
in_label="f-i-$1"
out_label="f-o-$1"

router_id=`neutron floatingip-show $1 | awk '/ router_id /{print $4}'`
fixed_ip=`neutron floatingip-show $1 | awk '/ fixed_ip_address /{print $4}'`

neutron meter-label-list | grep -q $in_label
if [[ $? -ne 0 ]]; then
    neutron meter-label-create $in_label --router_id=$router_id
else
    if test "`neutron meter-label-show $in_label | awk '/ router_id /{print $4}'`" != $router_id; then
        neutron meter-label-delete $in_label
        neutron meter-label-create $in_label --router_id=$router_id
    fi
fi
neutron meter-label-rule-create $in_label $fixed_ip/32 --reverse
neutron meter-label-rule-create $in_label $IPC_IP_CIDR --excluded

neutron meter-label-rule-create "r-i-$router_id" $fixed_ip/32 --reverse --excluded

neutron meter-label-list | grep -q $out_label
if [[ $? -ne 0 ]]; then
    neutron meter-label-create $out_label --router_id=$router_id
else
    if test "`neutron meter-label-show $out_label | awk '/ router_id /{print $4}'`" != $router_id; then
        neutron meter-label-delete $out_label
        neutron meter-label-create $out_label --router_id=$router_id
    fi
fi
neutron meter-label-rule-create $out_label $fixed_ip/32 --reverse --direction=egress
neutron meter-label-rule-create $out_label $IPC_IP_CIDR --excluded --direction=egress

neutron meter-label-rule-create "r-o-$router_id" $fixed_ip/32 --reverse --excluded --direction=egress

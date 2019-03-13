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

fixed_ip=`neutron floatingip-show $1 | awk '/ fixed_ip_address /{print $4}'`
floating_ip=`neutron floatingip-show $1 | awk '/ floating_ip_address /{print $4}'`
router_id=`neutron floatingip-show $1 | awk '/ router_id /{print $4}'`
router_gw_ip=`neutron router-show $router_id | awk -F'"' '/external_gateway_info/{print $16}'`

i_label="$floating_ip-fi"
o_label="$floating_ip-fo"
i_router_label="$router_gw_ip-ri"
o_router_label="$router_gw_ip-ro"

neutron meter-label-list | grep -q $i_label
if [[ $? -ne 0 ]]; then
    neutron meter-label-create $i_label --router_id=$router_id
else
    if test "`neutron meter-label-show $i_label | awk '/ router_id /{print $4}'`" != $router_id; then
        neutron meter-label-delete $i_label
        neutron meter-label-create $i_label --router_id=$router_id
    fi
fi
neutron meter-label-rule-create $i_label $fixed_ip/32 --reverse
neutron meter-label-rule-create $i_label $IPC_IP_CIDR --excluded

neutron meter-label-rule-create "$i_router_label" $fixed_ip/32 --reverse --excluded

neutron meter-label-list | grep -q $o_label
if [[ $? -ne 0 ]]; then
    neutron meter-label-create $o_label --router_id=$router_id
else
    if test "`neutron meter-label-show $o_label | awk '/ router_id /{print $4}'`" != $router_id; then
        neutron meter-label-delete $o_label
        neutron meter-label-create $o_label --router_id=$router_id
    fi
fi
neutron meter-label-rule-create $o_label $fixed_ip/32 --reverse --direction=egress
neutron meter-label-rule-create $o_label $IPC_IP_CIDR --excluded --direction=egress

neutron meter-label-rule-create "$o_router_label" $fixed_ip/32 --reverse --excluded --direction=egress

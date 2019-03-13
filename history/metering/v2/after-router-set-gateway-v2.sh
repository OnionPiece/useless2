#!/bin/bash

if test -z $1; then
    echo "need router-id as parameter"
    exit 1
fi

source ~/openrc
if test "`neutron router-show $1 | awk '/ id /{print $4}'`" != $1; then
    echo "need router-id as parameter"
    exit 1
fi

IPC_IP_CIDR=172.16.0.12/32

gw_ip=`neutron router-show $1 | awk -F'"' '/external_gateway_info/{print $16}'`
i_label="$gw_ip-ri"
o_label="$gw_ip-ro"

neutron meter-label-create $i_label --router_id=$1
neutron meter-label-rule-create $i_label 0.0.0.0/0
neutron meter-label-rule-create $i_label $IPC_IP_CIDR --excluded

neutron meter-label-create $o_label --router_id=$1
neutron meter-label-rule-create $o_label 0.0.0.0/0 --direction=egress
neutron meter-label-rule-create $o_label $IPC_IP_CIDR --excluded --direction=egress

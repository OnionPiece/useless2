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

router_gateway_port_id=`neutron port-list --device_id=$1 --device_owner=network:router_gateway | awk '{if(NR>3)print $2}'`
i_label="$router_gateway_port_id-ri"
o_label="$router_gateway_port_id-ro"

neutron meter-label-delete $i_label
neutron meter-label-delete $o_label

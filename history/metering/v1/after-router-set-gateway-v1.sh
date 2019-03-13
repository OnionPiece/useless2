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
in_label="r-i-$1"
out_label="r-o-$1"

neutron meter-label-create $in_label --router_id=$1
neutron meter-label-rule-create $in_label 0.0.0.0/0
neutron meter-label-rule-create $in_label $IPC_IP_CIDR --excluded

neutron meter-label-create $out_label --router_id=$1
neutron meter-label-rule-create $out_label 0.0.0.0/0 --direction=egress
neutron meter-label-rule-create $out_label $IPC_IP_CIDR --excluded --direction=egress

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

i_label_name="$1-fi"
o_label_name="$1-fo"
i_label_id=`neutron meter-label-list --name=$i_label_name | awk '{if(NR>3)print $2}'`
o_label_id=`neutron meter-label-list --name=$o_label_name | awk '{if(NR>3)print $2}'`
for id in $i_label_id $o_label_id; do
    for i in `neutron meter-label-rule-list --metering_label_id=$id | awk '{if(NR>3)print $2}'`; do
        neutron meter-label-rule-delete $i
    done
done

router_id=`neutron floatingip-show $1 | awk '/ router_id /{print $4}'`
fixed_ip=`neutron floatingip-show $1 | awk '/ fixed_ip_address /{print $4}'`
router_gateway_port_id=`neutron port-list --device_id=$router_id --device_owner=network:router_gateway | awk '{if(NR>3)print $2}'`
i_router_label="$router_gateway_port_id-ri"
o_router_label="$router_gateway_port_id-ro"
i_router_label_id=`neutron meter-label-list --name=$i_router_label | awk '{if(NR>3)print $2}'`
o_router_label_id=`neutron meter-label-list --name=$o_router_label | awk '{if(NR>3)print $2}'`
fixed_ip_cidr="$fixed_ip/32"
for id in $i_router_label_id $o_router_label_id; do
    for i in `neutron meter-label-rule-list --metering_label_id=$id --remote_ip_prefix=$fixed_ip_cidr | awk '{if(NR>3)print $2}'`; do
        neutron meter-label-rule-delete $i
    done
done

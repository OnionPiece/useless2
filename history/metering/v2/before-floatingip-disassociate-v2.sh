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

router_id=`neutron floatingip-show $1 | awk '/ router_id /{print $4}'`
fixed_ip=`neutron floatingip-show $1 | awk '/ fixed_ip_address /{print $4}'`
floating_ip=`neutron floatingip-show $1 | awk '/ floating_ip_address /{print $4}'`
router_gw_ip=`neutron router-show $router_id | awk -F'"' '/external_gateway_info/{print $16}'`

i_label_name="$floating_ip-fi"
o_label_name="$floating_ip-fo"
i_label_id=`neutron meter-label-list --name=$i_label_name | awk '{if(NR>3)print $2}'`
o_label_id=`neutron meter-label-list --name=$o_label_name | awk '{if(NR>3)print $2}'`
i_router_label_name="$router_gw_ip-ri"
o_router_label_name="$router_gw_ip-ro"
i_router_label_id=`neutron meter-label-list --name=$i_router_label_name | awk '{if(NR>3)print $2}'`
o_router_label_id=`neutron meter-label-list --name=$o_router_label_name | awk '{if(NR>3)print $2}'`

for id in $i_label_id $o_label_id; do
    for i in `neutron meter-label-rule-list --metering_label_id=$id | awk '{if(NR>3)print $2}'`; do
        neutron meter-label-rule-delete $i
    done
done

fixed_ip_cidr="$fixed_ip/32"

for id in $i_router_label_id $o_router_label_id; do
    for i in `neutron meter-label-rule-list --metering_label_id=$id --remote_ip_prefix=$fixed_ip_cidr | awk '{if(NR>3)print $2}'`; do
        neutron meter-label-rule-delete $i
    done
done

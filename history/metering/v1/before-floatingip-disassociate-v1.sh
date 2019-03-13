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

in_label_name="f-i-$1"
out_label_name="f-o-$1"
in_label_id=`neutron meter-label-list --name=$in_label_name | awk '{if(NR>3)print $2}'`
out_label_id=`neutron meter-label-list --name=$out_label_name | awk '{if(NR>3)print $2}'`
in_router_label_name="r-i-$router_id"
out_router_label_name="r-o-$router_id"
in_router_label_id=`neutron meter-label-list --name=$in_router_label_name | awk '{if(NR>3)print $2}'`
out_router_label_id=`neutron meter-label-list --name=$out_router_label_name | awk '{if(NR>3)print $2}'`

for id in $in_label_id $out_label_id; do
    for i in `neutron meter-label-rule-list --metering_label_id=$id | awk '{if(NR>3)print $2}'`; do
        neutron meter-label-rule-delete $i
    done
done

fixed_ip_cidr="$fixed_ip/32"

for id in $in_router_label_id $out_router_label_id; do
    for i in `neutron meter-label-rule-list --metering_label_id=$id --remote_ip_prefix=$fixed_ip_cidr | awk '{if(NR>3)print $2}'`; do
        neutron meter-label-rule-delete $i
    done
done

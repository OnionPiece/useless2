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

floating_ip=`neutron floatingip-show $1 | awk '/ floating_ip_address /{print $4}'`
i_label_name="$floating_ip-fi"
o_label_name="$floating_ip-fo"

neutron meter-label-delete $i_label_name
neutron meter-label-delete $o_label_name

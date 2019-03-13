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

in_label_name="f-i-$1"
out_label_name="f-o-$1"

neutron meter-label-delete $in_label_name
neutron meter-label-delete $out_label_name

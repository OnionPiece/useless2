#!/bin/bash

# run as admin, demo or alt_demo
source /opt/stack/devstack/openrc $1 $1
ext_net_id="7b2f5040-9296-4b29-b77f-48b72baa760f"
ext_ip_hd="172.16.0."
first_ext_ip_id=130
last_ext_ip_id=$((200 + 1))
creation_count=10

declare -a allocated_ids=()

function create
{
    if test -z $1; then
        result=`neutron managed-extip-create $ext_net_id 2>&1`
    else
        result=`neutron managed-extip-create $ext_net_id --ip-address $1 2>&1`
    fi
    if [[ ${result:0:7} == "Created" ]]; then
        allocated_ids[${#allocated_ids[@]}]=`echo $result | awk '{print $15}'`
    else
        if [[ "${result:0:35}${result:77:100}" == "All managed external IPs on subnets have been allocated, no more available." || "${result:0:19}${result:32:100}" == "Managed external IP is in use" ]]; then
            #echo "Failed to create with $1, reason: $result"
            :
        else:
            echo "Unknow error: $result"
        fi
    fi
}

function random_creations
{
    # creation with specified ip_address
    for i in `python -c "import random; print ' '.join(str(random.sample(range($first_ext_ip_id, $last_ext_ip_id), $creation_count))[1:-1].split(','))"`; do
        create ${ext_ip_hd}${i}
    done
}

function default_creations
{
    for((i=0;i!=${creation_count};i++)); do
        create
    done
}

function deallocate
{
    if [[ $1 == "all" ]]; then
        delete_count=${#allocated_ids[@]}
    else
        delete_count=$creation_count
    fi
    for((i=0;i!=${delete_count};i++)); do
        neutron managed-extip-delete ${allocated_ids[0]}
        allocated_ids=(${allocated_ids[@]:1})
    done
}

random_creations
default_creations
echo "2 blocks tested..., 9 left behind"
random_creations
default_creations
echo "4 blocks tested..., 7 left behind"

deallocate
random_creations
default_creations
echo "7 blocks tested..., 4 left behind"

deallocate
deallocate
echo "9 blocks tested..., 2 left behind"
random_creations
default_creations
echo "All 11 blocks tested... it's cleanup time"

deallocate "all"
#for i in `neutron managed-extip-list | awk '{print $2}'`; do neutron managed-extip-delete $i; done

#!/bin/bash

ns_name=`ip netns identify`
if [[ $ns_name != '' ]]; then
    echo "cannot run inside a netns"
    exit 1
fi
ns_name='qrouter-7559b358-6cf4-4900-9c7d-99046bbad2db'
tc="ip netns exec $ns_name tc"
dev=`ip netns exec $ns_name ip a | awk -F":" '/: qg-/{print $2}'`
ifb_dev=`ip netns exec $ns_name ip a | awk -F":" '/: ifb-/{print $2}'`

function _tc_show
{
    echo "+++++++++++++++++++++++++++++++ tc $1 show | $2 +++++++++++++++++++++++++++++++++++++"
    if [[ $2 == "ingress" ]]; then
        _dev=$ifb_dev
    else
        _dev=$dev
    fi
    if [[ $1 == "filter" ]]; then
        $tc $1 show dev $_dev
        $tc $1 show dev $_dev parent ffff:
    else
        $tc $1 show dev $_dev
    fi
    echo "------------------------------- end of tc $1 show | $2 ------------------------------"
    echo ""
}

function tc_show
{
    _tc_show qdisc egress
    _tc_show class egress
    _tc_show filter egress
    _tc_show qdisc ingress
    _tc_show class ingress
    _tc_show filter ingress
}

function init
{
    bash fip-disassociate-api.sh > /dev/null
    sed -i "s/\"rate_limit_kbps\":.*$/\"rate_limit_kbps\": 3072/g" fip-update-api.sh && bash fip-update-api.sh > /dev/null
    sed -i "s/\"rate_limit_kbps\":.*$/\"rate_limit_kbps\": 3072/g" router-update-api.sh && bash router-update-api.sh > /dev/null
    sleep 3
    echo "before running:"
    echo "fip status:"
    bash fip-show-api.sh | egrep "(status|rate_limit_kbps)"
    echo "router status:"
    bash router-show-api.sh | egrep "(status|rate_limit_kbps)"
    sleep 2
    tc_show

}

function fip-disas
{
    bash fip-disassociate-api.sh > /dev/null
    sleep 3
    echo "after fip disassocaite:"
    bash fip-show-api.sh | egrep "(status|rate_limit_kbps)"
    sleep 2
    tc_show
}

function fip-assoc
{
    bash fip-associate-api.sh > /dev/null
    sleep 3
    echo "after fip associate:"
    bash fip-show-api.sh | egrep "(status|rate_limit_kbps)"
    sleep 2
    tc_show
}

function fip-update
{
    sed -i "s/\"rate_limit_kbps\":.*$/\"rate_limit_kbps\": $1/g" fip-update-api.sh && bash fip-update-api.sh > /dev/null
    sleep 2
    echo "after fip update:"
    bash fip-show-api.sh | egrep "(status|rate_limit_kbps)"
    sleep 2
    tc_show
}

function router-update
{
    if [[ $1 == "gw-set" ]]; then
        bash router-gw-set-api.sh > /dev/null
    elif [[ $1 == "gw-clear" ]]; then
        bash router-gw-clear-api.sh > /dev/null
    else
        sed -i "s/\"rate_limit_kbps\":.*$/\"rate_limit_kbps\": $1/g" router-update-api.sh && bash router-update-api.sh > /dev/null
    fi
    sleep 3
    echo "after router update:"
    bash router-show-api.sh | egrep "(status|rate_limit_kbps)"
    sleep 2
    tc_show
}

echo "##################################  init  #########################################"
init

echo "################################## case 1 #########################################"
fip-assoc
fip-disas
echo ""
echo ""

echo "################################## case 2 #########################################"
fip-assoc
fip-update 1024
fip-update 2048
fip-update 0
fip-update 1024
fip-update "null"
fip-update 1024
fip-disas
echo ""
echo ""

echo "################################## case 3 #########################################"
fip-update 0
fip-assoc
fip-update 1024
fip-disas
echo ""
echo ""

echo "################################## case 4 #########################################"
router-update 1024
fip-assoc
router-update 2048
router-update 0
router-update 2048
router-update null
router-update 2048
fip-disas
echo ""
echo ""

echo "################################## case 5 #########################################"
echo ""
echo ""

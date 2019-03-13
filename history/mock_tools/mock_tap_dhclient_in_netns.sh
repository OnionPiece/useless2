#!/bin/bash
# writen by zongkai@polex.com.cn

if test -z $1; then
    echo "need assign tap device to mock."
    ip l | grep tap | cut -d ':' -f 2
    exit 1
else
    ip l | grep -q $1
    if [[ $? -ne 0 ]]; then
        echo "unknown device, are you sure it's an existing tap device?"
        exit 1
    fi
fi

tap_to_mock=$1
mac_to_mock=`ip l show $tap_to_mock | awk '/ link\/ether /{print $2}'`
mac_to_mock="fa:"${mac_to_mock:3:14}

ovs-vsctl list-ports br-int | grep -q $tap_to_mock
if [[ $? -eq 0 ]];then
    tag_to_mock=`ovs-vsctl get port $tap_to_mock tag`
else
    tag_to_mock=`ovs-vsctl get port "qvo"${tap_to_mock:3:11} tag`
fi

ip netns add test
ovs-vsctl add-port br-int ppp -- set interface ppp type=internal -- set port ppp tag=${tag_to_mock} -- set interface ppp mac=\"${mac_to_mock}\"
ip l set dev ppp netns test
ip netns exec test ip l set ppp up

timeout 5 ip netns exec test dhclient ppp
if [[ $? -ne 0 ]]; then
    echo "Unknown error."
    ip netns exec test cat /var/run/dhclient.pid | xargs kill -9
    exit 2
fi
exit 0

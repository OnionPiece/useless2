#!/bin/bash
# writen by zongkai@polex.com.cn

ip netns exec test cat /var/run/dhclient.pid | xargs kill -9
ip netns del test
ovs-vsctl del-port br-int ppp

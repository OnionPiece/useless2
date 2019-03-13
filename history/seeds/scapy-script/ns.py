!/usr/bin/python

# http://packetlife.net/blog/2009/feb/2/ipv6-neighbor-spoofing/

from scapy.all import *
import time
import os

dst='fd81:ce49:a948:0:f816:3eff:fe46:8a42'
dll='33:33:ff:' + dst[-7:-2] + ':' + dst[-2:]

net_config = '/home/ubuntu/net.config'
sll = os.popen("awk '/src_port_mac/{print $2}' %s" % net_config).read().split()[0]
src = os.popen("awk '/src_port_ip6_ula/{print $2}' %s" % net_config).read().split()[0]

# for dhcp: we must have conf.iface been set, no matter eth0, eth1, br-ex,
#     or br-eth1 without setting this, the discovery request will use local
#     ip to send, not 0.0.0.0, don't know the reason yet
# for arp: we nedd make sure the interface we are using is in the same
#     subnet to arp requestor
conf.iface = 'eth1'

# send dhcp-discovery
conf.checkIPaddr = False

ether=Ether(src=sll, dst=dll)

ipv6=IPv6(nh=58, dst=dst, src=src, version=6L, hlim=255, plen=32, fl=0L, tc=0L)

na=ICMPv6ND_NA(code=0, type=135, R=0, S=1, tgt=dst)

lla=ICMPv6NDOptSrcLLAddr(type=1, len=1, lladdr=sll)

(ether/ipv6/na/lla).display()

sendp(ether/ipv6/na/lla, iface="ppp", loop=1, inter=1)

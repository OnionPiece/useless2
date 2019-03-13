#!/usr/bin/python

# http://packetlife.net/blog/2009/feb/2/ipv6-neighbor-spoofing/

from scapy.all import *
import time
import os

src = 'fd81:ce49:a948:0:f816:3eff:fee5:4d5e'
sll = 'fa:16:3e:' + src[-7:-2] + ':' + src[-2:]

net_config = '/home/ubuntu/net.config'
dll = os.popen("awk '/src_port_mac/{print $2}' %s" % net_config).read().split()[0]
dst = os.popen("awk '/src_port_ip6_ula/{print $2}' %s" % net_config).read().split()[0]

# for dhcp: we must have conf.iface been set, no matter eth0, eth1, br-ex,
#     or br-eth1 without setting this, the discovery request will use local
#     ip to send, not 0.0.0.0, don't know the reason yet
# for arp: we nedd make sure the interface we are using is in the same
#     subnet to arp requestor
conf.iface = 'eth1'

# send dhcp-discovery
conf.checkIPaddr = False

ether=Ether(dst=dll,src=sll)

ipv6=IPv6(nh=58, src=src, dst=dst, version=6L, hlim=255, plen=32, fl=0L, tc=0L)

na=ICMPv6ND_NA(code=0, type=136, R=0, S=1, tgt=src)

lla=ICMPv6NDOptDstLLAddr(type=2, len=1, lladdr=sll)

(ether/ipv6/na/lla).display()

sendp(ether/ipv6/na/lla, iface='ppp', loop=1, inter=1)

#!/usr/bin/python

# http://packetlife.net/blog/2009/feb/2/ipv6-neighbor-spoofing/

from scapy.all import *
import time

# for dhcp: we must have conf.iface been set, no matter eth0, eth1, br-ex,
#     or br-eth1 without setting this, the discovery request will use local
#     ip to send, not 0.0.0.0, don't know the reason yet
# for arp: we nedd make sure the interface we are using is in the same
#     subnet to arp requestor
conf.iface = 'eth1'

dst='20.0.0.3'
dll='ff:ff:ff:ff:ff:ff'

src='10.0.0.3'
sll='fa:16:3e:94:05:98'

# send dhcp-discovery
conf.checkIPaddr = False

ether=Ether(src=sll, dst=dll)

arp=ARP(pdst=dst,psrc=src,hwdst=dll,hwsrc=sll)

(ether/arp).display()

sendp(ether/arp, iface="ppp", loop=1, inter=1)

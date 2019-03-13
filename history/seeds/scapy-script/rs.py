#!/usr/bin/python

# http://packetlife.net/blog/2009/feb/2/ipv6-neighbor-spoofing/

from scapy.all import *
import time
import os
import sys

if len(sys.argv) != 2:
    print "Usage: python %s tap-**" % (sys.argv[0])
    sys.exit(1)

src_mac = os.popen("mysql -uroot -ppassword \"neutron\" -e \"select * from ports\" | awk '/%s/{print $4}'" % sys.argv[1][3:]).read().strip()
print src_mac
if not src_mac or ':' not in src_mac:
    print "Usage: python %s tap-**" % (sys.argv[0])
    sys.exit(1)

src_lla="fe80::f816:3eff:fe"+src_mac[-8:-5]+src_mac[-5:-3]+src_mac[-2:]

# for dhcp: we must have conf.iface been set, no matter eth0, eth1, br-ex,
#     or br-eth1 without setting this, the discovery request will use local
#     ip to send, not 0.0.0.0, don't know the reason yet
# for arp: we nedd make sure the interface we are using is in the same
#     subnet to arp requestor
conf.iface = 'eth1'

# send dhcp-discovery
conf.checkIPaddr = False

ether=Ether(src=src_mac,dst="33:33:00:00:00:02")

ipv6=IPv6(nh=58, src=src_lla, dst='ff02::2', version=6L, hlim=255, plen=16, fl=0L, tc=0L)

rs=ICMPv6ND_RS(code=0, type=133)

lla=ICMPv6NDOptSrcLLAddr(type=1, len=1, lladdr=src_mac)

(ether/ipv6/rs/lla).display()

sendp(ether/ipv6/rs/lla, iface="ppp", loop=1, inter=1)

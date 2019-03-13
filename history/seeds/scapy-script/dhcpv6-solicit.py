#!/usr/bin/python

from scapy.all import *
import time

vm_src="b4:63:75"
prefix="fdd5:edde:a711::"

src="fa:16:3e:"+vm_src
eui64="f816:3eff:fe"+vm_src[:5]+vm_src[-2:]
lla="fe80::"+eui64
offer_ip=prefix+eui64

eth = Ether(src=src,dst="ff:ff:ff:ff:ff:ff")
ip = IPv6(src=lla,dst="ff02::1:2")
udp = UDP(sport=546,dport=547)

transaction_id=0x10203
dhcp6 = DHCP6(msgtype=1,trid=transaction_id)

duid=DUID_LL(lladdr=src)
client_id=DHCP6OptClientId(optlen=0xa,duid=duid)

#ianaopts=DHCP6OptIAAddress(addr=offer_ip)
#ia_na=DHCP6OptIA_NA(optlen=12,iaid=0x1020304,T1=0xe10,T2=0x1518,ianaopts=ianaopts)
#(eth/ip/udp/dhcp6/client_id/ia_na).display()
#sendp(eth/ip/udp/dhcp6/client_id/ia_na, iface="ppp", count=1)

ia_na=DHCP6OptIA_NA(optlen=12,iaid=0x1020304,T1=0xe10,T2=0x1518)
(eth/ip/udp/dhcp6/client_id/ia_na).display()
sendp(eth/ip/udp/dhcp6/client_id/ia_na, iface="ppp", count=1)

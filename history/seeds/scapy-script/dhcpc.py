#!/usr/bin/python

from scapy.all import *
import time


eth = Ether(src="fa:16:3e:94:05:98",dst="ff:ff:ff:ff:ff:ff")
ip = IP(src="0.0.0.0",dst="255.255.255.255")
udp = UDP(sport=68,dport=67)
bp = BOOTP(chaddr="fa:16:3e:94:05:98")
dhcp_discover = DHCP(options=[("message-type","discover"),"end"])
dhcp_req = DHCP(options=[("message-type", "request")])


while 1:
    sendp(eth/ip/udp/bp/dhcp_discover, iface="ppp", count=1)
    time.sleep(2)
    #sendp(eth/ip/udp/bp/dhcp_req, iface="ppp", count=1)
#ans, unans = srp(dhcp_discover, multi=True, timeout=5, filter="udp and host %s" % _dns)
#
#dns_hwaddr = ans[0][1][Ether].dst
#yiaddr = ans[0][1][BOOTP].yiaddr
#dhcp_opts = ans[0][1][DHCP].options
#print yiaddr, dhcp_opts
#server_id = [opt[1] for opt in dhcp_opts if opt[0] == "server_id"][0]
#
## send dhcp-request
## check /usr/lib/python2.7/site-packages/scapy/layers/dhcp.py for more details
##50: IPField("requested_addr","0.0.0.0"),
##54: IPField("server_id","0.0.0.0"),
#dhcp_discover = Ether(dst="ff:ff:ff:ff:ff:ff")/IP(src="0.0.0.0",dst="255.255.255.255")/UDP(sport=68,dport=67)/BOOTP(chaddr=hw)/DHCP(options=[("message-type","request"), ("server_id", server_id), ("requested_addr", yiaddr), "end"])
#ans, unans = srp(dhcp_discover, multi=True, timeout=5, filter="udp and host %s" % _dns)
#print ans[0][1][DHCP].options
#
#
## send arp response to dhcp server (necessary?)
## try use class ARP_am, method make_reply
#arp_req = Ether(dst=dns_hwaddr, src=_hw)/ARP(op="is-at", hwsrc=_hw, psrc=yiaddr, hwdst=dns_hwaddr, pdst=_dns)
##<Ether  dst=00:50:56:ae:7e:87 src=00:50:56:ae:17:31 type=ARP |<ARP  hwtype=0x1 ptype=IPv4 hwlen=6 plen=4 op=is-at hwsrc=00:50:56:ae:17:31 psrc=192.168.0.130 hwdst=00:50:56:ae:7e:87 pdst=192.168.0.133 |<Padding  load='\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' |>
##ans, unans = srp(arp_req, multi=True, timeout=5)
#sendp(arp_req, iface="ppp", count=1)
#time.sleep(1)
#sendp(arp_req, iface="ppp", count=1)
#time.sleep(1)
#sendp(arp_req, iface="ppp", count=1)

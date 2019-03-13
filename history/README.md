This idea of this project is to create some basic tools to help people check
there virtual network datapaths, especially for VM. Like, why VM cannot get IP,
why VM cannot ping subnet GW, to find out where get break in the datapath.

To have an esay beginning, to have a small scope, I will build it only works
our environment, like the "stage" environment. This will define a lot of
environment limitations for the tools in this project to use, like:
 - DHCP: using dnsmasq as DHCP server.
 - ML2: using OVS + VXLAN.
 - Control plane: Neutron.
 - Nodes: no mutual trust nodes in env. (This means user need to run tools on
                                         different nodes.)

Ready for use now:
 - vm-connect-tools/
  - build-intf-to-reach-vm.sh
  - clean-intf-to-reach-vm.sh

Update:
 - 2016.12.17:
   - add some scripts I used before as seeds and weeds, hope I can use them
     in this project. I need update them first to fit our env.
 - 2017.1.7:
   - add build-intf-to-reach-vm-v2.sh:
     - add variable "base_mac" to calculate VM mac;
     - fix: list tap devices to mock, and get ofp device ofport
     - add ping6 check, and if fails try to add ip6tables rule to pass
   - clean-intf-to-reach-vm-v2.sh:
     - add cleanup for ip6tables rules if find any
 - 2017.1.9:
    - build-intf-to-reach-vm-v2.sh:
     - add ping retry test;
     - rename to build-intf-to-reach-vm.sh;
   - clean-intf-to-reach-vm-v2.sh:
     - rename to clean-intf-to-reach-vm.sh;
 - 2017.3.3:
   - Add helper script to describe ipsec-siteconns on DB node
     describe_ipsec_site_connection.sh
 - 2017.3.14:
   - Add helper scripts to build fake external network in OoO
     build_fake_ext_network_in_OoO, it has topology.txt in it to describe
     what kind of topology to handle.
 - 2017.3.21:
   - Add helper scripts to build mock dev in netns to mock dhcp requests from
     VM tap device, and clean job to clean dev & process resources.
   - Add dot\_files.
   - Add helper scripts to describe port background info, such as related SG
     rules, router_interface, router, fip.
   - Add helper scripts to do ping check on network node.
     ping_checker/ping_checker_R2I.sh
   - Add bin/arping2
   - Add helper script to build arp responder flow:
     mock_tools/build_arp_responder.sh
     update build_fake_ext_network_in_OoO/update_br_ex_arp_responder_on_ctrl.sh
 - 2017.4.1:
   - Add install\_bashrc.py to append data from dot\_bashrc into ~/.bashrc

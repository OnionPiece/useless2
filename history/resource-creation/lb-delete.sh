source ~/openrc
neutron lbaas-healthmonitor-delete hm1
neutron lbaas-member-delete mem1 pl1
neutron lbaas-member-delete mem2 pl1
neutron lbaas-member-delete mem3 pl1
neutron lbaas-member-delete mem4 pl1
neutron lbaas-pool-delete pl1
neutron lbaas-listener-delete lst1
neutron lbaas-loadbalancer-delete lb1

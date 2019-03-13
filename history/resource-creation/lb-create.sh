source ~/openrc
pending_order=0
neutron lbaas-loadbalancer-create --name lb1 sn1
if [[ $pending_order -ne 0 ]]; then
    neutron lbaas-listener-create --loadbalancer lb1 --protocol TCP --protocol-port 80 --name lst1
    neutron lbaas-pool-create --name pl1 --listener lst1 --loadbalancer lb1 --lb-algorithm ROUND_ROBIN --protocol TCP
else
    neutron lbaas-pool-create --name pl1 --loadbalancer lb1 --lb-algorithm ROUND_ROBIN --protocol TCP
fi
neutron lbaas-member-create --name mem1 --subnet sn1 --address 10.0.0.5 --protocol-port 80 pl1
neutron lbaas-member-create --name mem2 --subnet sn1 --address 10.0.0.32 --protocol-port 80 pl1
neutron lbaas-member-create --name mem3 --subnet sn2 --address 20.0.0.5 --protocol-port 80 pl1
neutron lbaas-member-create --name mem4 --subnet sn2 --address 20.0.0.6 --protocol-port 80 pl1
neutron lbaas-healthmonitor-create --name hm1 --delay 3 --max-retries 3 --timeout 3 --type TCP --pool pl1
if [[ $pending_order -eq 0 ]]; then
    neutron lbaas-listener-create --loadbalancer lb1 --protocol TCP --protocol-port 80 --name lst1 --default-pool pl1
    :
fi

lb_vip_port=`neutron lbaas-loadbalancer-list | awk '/ lb1 /{print $2}' | xargs -I {} neutron port-list -c id --device_id={} | awk '{if(NR==4)print $2}'`
neutron floatingip-associate e313f515-ade0-4d45-be81-d63f617dfc1c $lb_vip_port

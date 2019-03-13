source ~/openrc

num=3
router="oceana-vpn-test-r"
net="oceana-vpn-test-n"
snet="oceana-vpn-test-snet"
ike="oceana-vpn-test-ike"
policy="oceana-vpn-test-ipsecplicy"
vpnsvc="oceana-vpn-test-vpnservice"
epgroup="oceana-vpn-test-endpoint-group"
siteconn="oceana-vpn-test-ipsec-siteconn"

#
for((i=1;i<=$num;i++)); do
    for((j=1;j<=$num;j++)); do
        if [[ $i -eq $j ]]; then
            continue
        fi
        neutron ipsec-site-connection-delete ${siteconn}-r${i}-r${j}-1
        neutron ipsec-site-connection-delete ${siteconn}-r${i}-r${j}-2
    done
done

#
for((i=1;i<=$num;i++)); do
    neutron vpn-endpoint-group-delete ${epgroup}-r${i}-1-l
    neutron vpn-endpoint-group-delete ${epgroup}-r${i}-1-p
    neutron vpn-endpoint-group-delete ${epgroup}-r${i}-2-l
    neutron vpn-endpoint-group-delete ${epgroup}-r${i}-2-p
done

#
for((i=1;i<=$num;i++)); do
    neutron vpn-service-delete ${vpnsvc}${i}
done

#
neutron vpn-ikepolicy-delete $ike
neutron vpn-ipsecpolicy-delete $policy

#
for((i=1;i<=$num;i++)); do
    neutron router-gateway-clear ${router}${i}
    neutron router-interface-delete ${router}${i} ${snet}${i}
    neutron router-interface-delete ${router}${i} ${snet}1${i}
    neutron router-interface-delete ${router}${i} ${snet}2${i}
    neutron router-delete ${router}${i}
    neutron net-delete ${net}${i}
done

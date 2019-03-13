source ~/openrc

num=3
ext_net="ext"
router="oceana-vpn-test-r"
net="oceana-vpn-test-n"
snet="oceana-vpn-test-snet"
ike="oceana-vpn-test-ike"
policy="oceana-vpn-test-ipsecplicy"
vpnsvc="oceana-vpn-test-vpnservice"
epgroup="oceana-vpn-test-endpoint-group"
siteconn="oceana-vpn-test-ipsec-siteconn"
cidr_h="123.45"

declare -a router_ids=()
router_ids+=(0)
# create routers
for((i=1;i<=$num;i++)); do
    neutron router-create ${router}${i}
    neutron router-gateway-set ${router}${i} $ext_net
    router_id=`neutron router-show ${router}${i} -c external_gateway_info | awk -F'"' '{if(NR==4)print $16}'`
    router_ids+=($router_id)
done

# create net, snet, attach snet to router
for((i=1;i<=$num;i++)); do
    neutron net-create ${net}${i}
    neutron subnet-create --name ${snet}${i} ${net}${i} ${cidr_h}.${i}.0/24
    neutron subnet-create --name ${snet}1${i} ${net}${i} ${cidr_h}.1${i}.0/24
    neutron subnet-create --name ${snet}2${i} ${net}${i} ${cidr_h}.2${i}.0/24
    neutron router-interface-add ${router}${i} ${snet}${i}
    neutron router-interface-add ${router}${i} ${snet}1${i}
    neutron router-interface-add ${router}${i} ${snet}2${i}
done

#
neutron vpn-ikepolicy-create $ike
neutron vpn-ipsecpolicy-create $policy

#
for((i=1;i<=$num;i++)); do
    neutron vpn-service-create --name ${vpnsvc}${i} ${router}${i}
done

#
for((i=1;i<=$num;i++)); do
    neutron vpn-endpoint-group-create --name ${epgroup}-r${i}-1-l --type subnet --value ${snet}${i}
    neutron vpn-endpoint-group-create --name ${epgroup}-r${i}-1-p --type cidr --value ${cidr_h}.${i}.0/24
    neutron vpn-endpoint-group-create --name ${epgroup}-r${i}-2-l --type subnet --value ${snet}1${i} --value ${snet}2${i}
    neutron vpn-endpoint-group-create --name ${epgroup}-r${i}-2-p --type cidr --value ${cidr_h}.1${i}.0/24 --value ${cidr_h}.2${i}.0/24
done
  
#
for((i=1;i<=$num;i++)); do
    for((j=1;j<=$num;j++)); do
        if [[ $i -eq $j ]]; then
            continue
        fi
        neutron ipsec-site-connection-create --vpnservice-id ${vpnsvc}${i} --ikepolicy-id $ike --ipsecpolicy-id $policy \
          --peer-address ${router_ids[$j]} --peer-id ${router_ids[$j]} \
          --local-ep-group ${epgroup}-r${i}-1-l --peer-ep-group ${epgroup}-r${j}-1-p \
          --name ${siteconn}-r${i}-r${j}-1 --psk secret
        neutron ipsec-site-connection-create --vpnservice-id ${vpnsvc}${i} --ikepolicy-id $ike --ipsecpolicy-id $policy \
          --peer-address ${router_ids[$j]} --peer-id ${router_ids[$j]} \
          --local-ep-group ${epgroup}-r${i}-2-l --peer-ep-group ${epgroup}-r${j}-2-p \
          --name ${siteconn}-r${i}-r${j}-2 --psk secret
    done
done

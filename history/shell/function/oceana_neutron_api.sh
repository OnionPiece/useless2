#!/bin/bash
# writen by zongkai@polex.com.cn


OS_TOKEN=$OCEANA_OS_TOKEN
if [[ $OS_TOKEN == "" ]]; then
    echo "Fail to get OCEANA_OS_TOKEN, exit."
    path="$(cd `dirname $0`; pwd)"
    echo "Try to run \`source ${path%/*}/get_token.sh\` to set it."
    exit 1
fi

function oceana_neutron_api {
    token="-H \"X-Auth-Token: $OS_TOKEN\""
    case $1 in
        "net")
            resource="v2.0/networks"
            create_ret="not supported yet..."
            ;; 
        "snet")
            resource="v2.0/subnets"
            create_ret="not supported yet..."
            ;; 
        "port")
            resource="v2.0/ports"
            create_ret="not supported yet..."
            ;; 
        "fip")
            resource="v2.0/floatingips"
            create_ret="not supported yet..."
            ;; 
        "subnetpool")
            resource="v2.0/subnetpools"
            create_ret="not supported yet..."
            ;; 
        "router")
            resource="v2.0/routers"
            create_ret="not supported yet..."
            ;; 
        "fw")
            resource="v2.0/fw/firewalls"
            create_ret="not supported yet..."
            ;; 
        "fwp")
            resource="v2.0/fw/firewall_policies"
            create_ret="not supported yet..."
            ;; 
        "fwr")
            resource="v2.0/fw/firewall_rules"
            create_ret="not supported yet..."
            ;; 
        "sg")
            resource="v2.0/security-groups"
            create_ret="not supported yet..."
            ;; 
        "sgr")
            resource="v2.0/security-group-rules"
            create_ret="not supported yet..."
            ;; 
        "ike")
            resource="v2.0/vpn/ikepolicies"
            create_ret="not supported yet..."
            ;; 
        "ipsec")
            resource="v2.0/vpn/ipsecpolicies"
            create_ret="not supported yet..."
            ;; 
        "ipsec-siteconn")
            resource="v2.0/vpn/ipsec-site-connections"
            create_ret="not supported yet..."
            ;; 
        "epg")
            resource="v2.0/vpn/endpoint-groups"
            create_ret="not supported yet..."
            ;; 
        "vpn")
            resource="v2.0/vpn/vpnservices"
            create_ret="not supported yet..."
            ;; 
        "lb")
            resource="v2.0/lbaas/loadbalancers"
            create_ret="$curl POST http://$arg3:9696/${resource}.json $token -d '{\"loadbalancer\": {\"vip_subnet_id\": \"$arg4\", \"name\": \"$arg5\", \"admin_state_up\": true}}'"
        ;; 
        "lst")
            resource="v2.0/lbaas/listeners"
            create_ret="not supported yet..."
            ;; 
        "pl")
            resource="v2.0/lbaas/pools"
            create_ret="not supported yet..."
            ;; 
        "mem")
            if [[ $# -lt 4 ]]; then
                echo "not enough arguments found, at least 4"
                return
            fi
            last=$#
            pool_id=${!last}
            if [[ ${#pool_id} -ne 36 ]]; then
                echo "pool id must be the last argument"
                return
            fi
            resource="v2.0/lbaas/pools/$pool_id/members"
            create_ret="not supported yet..."
            ;; 
        #"hm")
        #    resource="v2.0/lbaas/healthmonitors"
        #    create_ret="not supported yet..."
        #    ;; 
        *)
            echo "unknown resource...or please update .bashrc"
            echo "support resource: net, snet, port, fip, router, subnetpool"
            echo "                  sg(securitygroup) sgr(securitygroup rule)"
            echo "                  fw(firewall) fwp(firewall policy) fwr(firewall rule)"
            echo "                  ike(ikepolicy) ipsec(ipsecpolicy) ipsec-siteconn(ipsec-site-connection) epg(endpoint-group) vpn(vpnservice)"
            echo "                  lb(loadbalancer) lst(listener) pl(pool) mem(member)"
            return
    esac
    arg3=${3-\$3}
    arg4=${4-\$4}
    arg5=${5-\$5}
    curl="curl -g -X"
    case $2 in
        "create")
            ret=$create_ret
            ;;
        "show")
            ret="$curl GET http://$arg3:9696/${resource}/${arg4}.json $token"
            ;;
        "show_n")$
            ret="$curl GET http://$arg3:9696/${resource}.json?fields=id\&name=${arg4} $token"
            ;;
        "list")
            ret="$curl GET http://$arg3:9696/${resource}.json $token"
            ;;
        "update")
            ret="not supported yet, please update .bashrc" 
            ;;
        "delete")
            ret="curl -g -i -X DELETE http://$arg3:9696/${resource}/${arg4}.json $token"
            ;;
        *)
            echo "unknown action, please specify an action, like create, update, show(id), show_n(name), delete, list"
            return
    esac
    echo $ret
    if [[ ${ret:0:4} == "curl" ]]; then
        echo "$ret" | sed 's/\$/\x01/g' | grep -aPq "\x01"
        if [[ $? -ne 0 ]]; then
            echo ""
            echo "tip: "
            echo "     ${ret/-i /} | python -mjson.tool"
            echo "     eval \`bash $0 $* | sed -n '1p'\` | python -mjson.tool"
            #echo "     eval \`oceana_neutron_api $* | sed -n '1p'\` | python -mjson.tool"
        else
            echo "you have necessary arguments not assigned"
        fi
    fi
}

oceana_neutron_api $*

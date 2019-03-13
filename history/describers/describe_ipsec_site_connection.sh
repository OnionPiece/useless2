router_vpnservice_map=/tmp/describe-ipsec-site-connection-routername-vpnserviceid-map.txt
peer_epg_id_cidr_map=/tmp/describe-ipsec-site-connection-peer-epg-id-cidr-map.txt
local_epg_id_subnet_map=/tmp/describe-ipsec-site-connection-loca-epg-id-cidr-map.txt

function get_subnet_by_local_epg_id
{
    echo `mysql -uroot "neutron" -e "select cidr,name,id from subnets where id in (select endpoint from vpn_endpoints where endpoint_group_id in (select id from vpn_endpoint_groups where endpoint_type='subnet' and id='"$1"'))" | awk '{if(NR>1)print $1"("$2","$3")"}'`
}

function init_local_epg_id_subnet_search_map
{
    echo '' > $local_epg_id_subnet_map
    for line in `mysql -uroot "neutron" -e "select subnets.cidr,subnets.name,subnets.id,vpn_endpoints.endpoint_group_id from subnets,vpn_endpoints where subnets.id=vpn_endpoints.endpoint and vpn_endpoints.endpoint_group_id in (select id from vpn_endpoint_groups where endpoint_type='subnet')" | awk '{if(NR>1)print $1","$2","$3","$4}'`; do
        echo $line >> $local_epg_id_subnet_map
    done
}

function get_subnet_by_peer_epg_id
{
    echo `mysql -uroot "neutron" -e "select endpoint from vpn_endpoints where endpoint_group_id in (select id from vpn_endpoint_groups where endpoint_type='cidr' and id='"$1"')" | awk '{if(NR>1)print $1}'`
}

function init_peer_epg_id_cidr_search_map
{
    echo '' > $peer_epg_id_cidr_map
    for line in `mysql -uroot "neutron" -e "select endpoint,endpoint_group_id from vpn_endpoints where endpoint_group_id in (select id from vpn_endpoint_groups where endpoint_type='cidr')" | awk '{if(NR>1)print $1","$2}'`; do
        echo $line >> $peer_epg_id_cidr_map
    done
}

function get_router_by_vpnservice_id
{
    echo `mysql -uroot "neutron" -e "select name from routers where id in (select router_id from vpnservices where id='"$1"')" | awk '{if (NR>1) print $0}'`
}

function init_router_search_map
{
    echo '' > $router_vpnservice_map
    for line in `mysql -uroot "neutron" -e "select routers.name,vpnservices.id from routers,vpnservices where routers.id=vpnservices.router_id" | awk '{if(NR>1) print $1","$2}'`; do
        echo $line >> $router_vpnservice_map
    done
}

function describe_per_ipsec_siteconn
{
    for ipsec_siteconn in `mysql -uroot "neutron" -e "select id,name,peer_address,peer_id,status,vpnservice_id,local_ep_group_id,peer_ep_group_id from ipsec_site_connections" | awk '{if(NR>1)print $1"|"$2"|"$3"|"$4"|"$5"|"$6"|"$7"|"$8}'`; do
        id=`echo $ipsec_siteconn | cut -d '|' -f 1`
        name=`echo $ipsec_siteconn | cut -d '|' -f 2`
        peer_address=`echo $ipsec_siteconn | cut -d '|' -f 3`
        peer_id=`echo $ipsec_siteconn | cut -d '|' -f 4`
        _status=`echo $ipsec_siteconn | cut -d '|' -f 5`
        vpnservice_id=`echo $ipsec_siteconn | cut -d '|' -f 6`
        local_epg_id=`echo $ipsec_siteconn | cut -d '|' -f 7`
        peer_epg_id=`echo $ipsec_siteconn | cut -d '|' -f 8`
    
        router_name=`grep $vpnservice_id $router_vpnservice_map | cut -d ',' -f 1`
        local_epg=`grep $local_epg_id $local_epg_id_subnet_map | cut -d ',' -f 1-3`
        peer_epg=`grep $peer_epg_id $peer_epg_id_cidr_map | cut -d ',' -f 1`

        echo "connection $name($id) for router $router_name is $_status"
        echo "    peer($peer_address|$peer_id)"
        echo "    left side:"
        for line in $local_epg; do
            echo "        $line"
        done
        echo "    right side:"
        for line in $peer_epg; do
            echo "        $line"
        done
    done
}

if ! test -z $1; then
    echo "reading db to init search map..."
    init_router_search_map
    init_peer_epg_id_cidr_search_map
    init_local_epg_id_subnet_search_map
fi
describe_per_ipsec_siteconn

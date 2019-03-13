# writen by zongkai@polex.com.cn

import netaddr

import api_cmd
import utils


@utils.dry
@utils.run_cmds
def ping_fip(**kwargs):
    fip_ip = kwargs['sub_resource']
    if not netaddr.valid_ipv4(fip_ip):
        raise utils.InnerException('%s is not a valid IPv4 address' % fip_ip)

    filters = {'floating_ip_address': fip_ip}
    fip_data = api_cmd.get_resources('floatingips', filters)[0]
    router = api_cmd.get_resource('routers', fip_data['router_id'])
    router_gw_ip = router['external_gateway_info'].get(
        'external_fixed_ips')[0]['ip_address']
    router_host = api_cmd.get_resource('router_host', router['id'])
    print router_host

# writen by zongkai@polex.com.cn

import collections
import itertools
import time

import api_cmd
import constants
import utils


vpn_demo_service_num = 3
vpn_demo_router = "oceana-vpn-test-r"
vpn_demo_net = "oceana-vpn-test-n"
vpn_demo_snet = "oceana-vpn-test-snet-%s"
vpn_demo_ike = "oceana-vpn-test-ike"
vpn_demo_policy = "oceana-vpn-test-ipsecplicy"
vpn_demo_vpnsvc = "oceana-vpn-test-vpnservice"
vpn_demo_epgroup = "oceana-vpn-test-endpoint-group-r"
vpn_demo_siteconn = "oceana-vpn-test-ipsec-siteconn-"
vpn_demo_cidr = "123.45.%s.0/24"

lb_demo_router = "oceana-lb-test-router"
lb_demo_net = "oceana-lb-test-n"
lb_demo_lb = "oceana-lb-test-lb"
lb_demo_pl = "oceana-lb-test-pool"
lb_demo_lst = "oceana-lb-test-listener"
lb_demo_hm = "oceana-lb-test-hm"
lb_demo_mem = "oceana-lb-test-mem"


def validate_and_get_ext_net():
    ext_net = api_cmd.get_resources('networks', {'router:external': True})
    if not ext_net:
        raise utils.InnerException(
            "We will not create external network, you should prepare it")
    return ext_net


def create_router(ext_net_id, name):
    data = {"router": {"external_gateway_info": {"network_id": ext_net_id},
                       "name": name}}
    return api_cmd.create_resource('routers', data)['router']


def create_net_and_attach_router(net_name, snet_num, cidr_fmt, router_id):
    data = {"network": {"name": net_name}}
    net = api_cmd.create_resource('networks', data)['network']
    net['subnets'] = []
    for i in range(snet_num):
        snet_cidr = cidr_fmt % i
        data = {"subnet": {"network_id": net['id'],
                           "cidr": snet_cidr, "ip_version": 4}}
        snet = api_cmd.create_resource('subnets', data)['subnet']
        api_cmd.update_resource(
            'add_router_intf', router_id,
            '{"subnet_id": "%s"}' % snet['id'])
        net['subnets'].append(snet)
    return net


def delete_demo_resource(**kwargs):
    if kwargs['demo_resc'] == 'lb':
        to_delete = collections.OrderedDict([
            ("lbaas/healthmonitors", lb_demo_hm),
            ("lbaas/pools", lb_demo_pl),
            ("lbaas/listeners", lb_demo_lst),
            ("lbaas/loadbalancers", lb_demo_lb),
            ('routers', lb_demo_router),
            ('networks', lb_demo_net),
        ])
    elif kwargs['demo_resc'] == 'vpn':
        to_delete = collections.OrderedDict([
            ('vpn/ipsec-site-connections', vpn_demo_siteconn),
            ('vpn/endpoint-groups', vpn_demo_epgroup),
            ('vpn/vpnservices', vpn_demo_vpnsvc),
            ('vpn/ikepolicies', vpn_demo_ike),
            ('vpn/ipsecpolicies', vpn_demo_policy),
            ('routers', vpn_demo_router),
            ('networks', vpn_demo_net),
        ])
    else:
        return

    for resc in to_delete:
        name_k = to_delete[resc]
        to_delete[resc] = []
        for item in api_cmd.get_resources(resc):
            if item['name'].startswith(name_k):
                to_delete[resc].append(item['id'])

    for resc in to_delete:
        if resc == "routers":
            break
        resc_ids = to_delete[resc]
        for resc_id in resc_ids:
            api_cmd.delete_resource(resc, resc_id)

    for router_id in to_delete['routers']:
        intf_filter = {'device_id': router_id,
                       'device_owner': constants.DEVICE_OWNERS['interface']}
        for intf in api_cmd.get_resources('ports', intf_filter):
            api_cmd.update_resource(
                'rm_router_intf', router_id,
                '{"subnet_id": "%s"}' % intf['fixed_ips'][0]['subnet_id'])

    for resc in ('routers', 'networks'):
        resc_ids = to_delete[resc]
        for resc_id in resc_ids:
            api_cmd.delete_resource(resc, resc_id)


@utils.run_cmds
def create_vpn_resource(**kwargs):
    ext_net_id = kwargs.get('e')
    if not ext_net_id:
        ext_net_id = validate_and_get_ext_net()[0]['id']
    num = vpn_demo_service_num
    routers = []
    try:
        for i in range(num):
            routers.append(create_router(
                ext_net_id, "%s%s" % (vpn_demo_router, i)))
    except utils.InnerException:
        if len(routers) < 2:
            raise utils.InnerException(
                'Cannot create vpn demo resources, since only one IP left in '
                'external network %s' % ext_net_id)
    num = len(routers)
    nets = []
    try:
        for i in range(num):
            net_name = "%s%s" % (vpn_demo_net, i)
            cidr_fmt = vpn_demo_cidr % ("1%s%s" % (i, '%s'))
            nets.append(create_net_and_attach_router(
                net_name, 3, cidr_fmt, routers[i]['id']))
    except utils.InnerException:
        if len(nets) < 2:
            raise utils.InnerException(
                'Cannot create vpn demo resources, since no more networks can '
                'be created')
    num = len(nets)

    data = {"ikepolicy": {
        "name": vpn_demo_ike, "auth_algorithm": "sha1", "pfs": "group5",
        "encryption_algorithm": "aes-128", "ike_version": "v1",
        "phase1_negotiation_mode": "main"}}
    ikepolicy = api_cmd.create_resource('ike', data)['ikepolicy']
    data = {"ipsecpolicy": {
        "name": vpn_demo_policy, "transform_protocol": "esp",
        "auth_algorithm": "sha1", "encapsulation_mode": "tunnel",
        "encryption_algorithm": "aes-128", "pfs": "group5"}}
    ipsecpolicy = api_cmd.create_resource('ipsec', data)['ipsecpolicy']

    vpnservices = []
    epgroups = {}

    def _create_epgroup(name, ep_type, eps):
        data = {"endpoint_group": {
            "endpoints": eps, "type": ep_type, "name": name}}
        return api_cmd.create_resource('epg', data)['endpoint_group']['id']

    for i in range(num):
        data = {"vpnservice": {
            "router_id": routers[i]['id'],
            "name": vpn_demo_vpnsvc + str(i)}}
        vpnservices.append(api_cmd.create_resource('vpn', data)['vpnservice'])

        epg_name = vpn_demo_epgroup + str(i) + '-1-l'
        eps = [nets[i]['subnets'][0]['id']]
        epgroups.update({epg_name: _create_epgroup(epg_name, "subnet", eps)})

        epg_name = vpn_demo_epgroup + str(i) + '-2-l'
        eps = [nets[i]['subnets'][1]['id'], nets[i]['subnets'][2]['id']]
        epgroups.update({epg_name: _create_epgroup(epg_name, "subnet", eps)})

        epg_name = vpn_demo_epgroup + str(i) + '-1-p'
        eps = [nets[i]['subnets'][0]['cidr']]
        epgroups.update({epg_name: _create_epgroup(epg_name, "cidr", eps)})

        epg_name = vpn_demo_epgroup + str(i) + '-2-p'
        eps = [nets[i]['subnets'][1]['cidr'], nets[i]['subnets'][2]['cidr']]
        epgroups.update({epg_name: _create_epgroup(epg_name, "cidr", eps)})

    for (i, j) in itertools.permutations(range(num), 2):
        data = {"ipsec_site_connection": {
            "psk": "secret", "initiator": "bi-directional",
            "vpnservice_id": vpnservices[i]['id'],
            "ikepolicy_id": ikepolicy['id'],
            "ipsecpolicy_id": ipsecpolicy['id'],
            "local_ep_group_id": epgroups[vpn_demo_epgroup + str(i) + '-1-l'],
            "peer_ep_group_id": epgroups[vpn_demo_epgroup + str(j) + '-1-p'],
            "peer_address": routers[j]['external_gateway_info'].get(
                'external_fixed_ips')[0]['ip_address'],
            "peer_id": routers[j]['external_gateway_info'].get(
                'external_fixed_ips')[0]['ip_address'],
            "name": vpn_demo_siteconn + 'r%s-r%s-1' % (i, j)}}
        api_cmd.create_resource("ipsec-siteconn", data)

        data["ipsec_site_connection"].update({
            "local_ep_group_id": epgroups[vpn_demo_epgroup + str(i) + '-2-l'],
            "peer_ep_group_id": epgroups[vpn_demo_epgroup + str(j) + '-2-p'],
            "name": vpn_demo_siteconn + 'r%s-r%s-2' % (i, j)})
        api_cmd.create_resource("ipsec-siteconn", data)


def demo_vpn(**kwargs):
    if kwargs['c']:
        create_vpn_resource(**kwargs)
    elif kwargs['d']:
        kwargs['demo_resc'] = 'vpn'
        delete_demo_resource(**kwargs)


def register_vpn():
    return [
        ('-c', {'help': 'Create demo vpn resource',
                'action': 'store_true'}),
        ('-d', {'help': 'Delete demo vpn resource',
                'action': 'store_true'}),
        ('-e',
         {'help': ('External network id to use to create demo vpn resource, '
                   'assign this when you have multiple external network')})]


def create_lb_resource(**kwargs):
    ext_net_id = validate_and_get_ext_net()[0]['id']
    router = create_router(ext_net_id, lb_demo_router)
    net_name1 = lb_demo_net + '1'
    net_name2 = lb_demo_net + '2'
    cidr_fmt1 = "123.56.1%s.0/24"
    vip_ip = "123.56.10.100"
    cidr_fmt2 = "123.56.2%s.0/24"
    net1 = create_net_and_attach_router(net_name1, 1, cidr_fmt1, router['id'])
    net2 = create_net_and_attach_router(net_name2, 1, cidr_fmt2, router['id'])

    data = {"loadbalancer": {
        "vip_subnet_id": net1['subnets'][0]['id'],
        "vip_address": vip_ip, "name": lb_demo_lb}}
    lb = api_cmd.create_resource('lb', data)['loadbalancer']

    def try_to_create(resc, data, parent_id=None):
        for i in range(5):
            res = api_cmd.create_resource(resc, data, parent_id)
            if res.keys()[0] != "NeutronError":
                return res.values()[0]
            time.sleep(1)

    data = {"pool": {
        "lb_algorithm": "ROUND_ROBIN", "protocol": "HTTP", "name": lb_demo_pl,
        "loadbalancer_id": lb['id']}}
    pl = try_to_create('pl', data)

    for net in (net1, net2):
        filters = {'network_id': net['id'],
                   'device_owner': constants.DEVICE_OWNERS['dhcp']}
        net_dhcp_ports = api_cmd.get_resources('ports', filters)
        mem_num = min(len(net_dhcp_ports), 2)
        for i in range(mem_num):
            snet_id = net_dhcp_ports[i]['fixed_ips'][0]['subnet_id']
            address = net_dhcp_ports[i]['fixed_ips'][0]['ip_address']
            data = {"member": {
                "subnet_id": snet_id, "protocol_port": "80",
                "name": lb_demo_mem + '1', "address": address}}
            try_to_create('mem', data, pl['id'])

    data = {"listener": {
        "protocol_port": "80", "protocol": "HTTP", "name": lb_demo_lst,
        "default_pool_id": pl['id'], "loadbalancer_id": lb['id']}}
    try_to_create('lst', data)

    data = {"healthmonitor": {
        "name": lb_demo_hm, "pool_id": pl['id'], "delay": "3",
        "max_retries": "3", "timeout": "3", "type": "TCP"}}
    try_to_create('hm', data)
    print ("Demo loadbalancer resource created completed. Try to use `nc` "
           "in demo netowrk dhcp namespace to work as fake server")


def demo_lb(**kwargs):
    if kwargs['c']:
        create_lb_resource(**kwargs)
    elif kwargs['d']:
        kwargs['demo_resc'] = 'lb'
        delete_demo_resource(**kwargs)


def register_lb():
    return [
        ('-c', {'help': 'Create demo loadbalancer resource',
                'action': 'store_true'}),
        ('-d', {'help': 'Delete demo loadbalancer resource',
                'action': 'store_true'})]

# writen by zongkai@polex.com.cn

import api_cmd
import constants as const
import utils


@utils.run_cmds
def list_haproxy_stat(sub_resource, **kwargs):
    stat = kwargs.get('stat', None) or '/var/lib/haproxy/stats'
    sub_resource = '' if sub_resource == 'any' else sub_resource
    return (
        'echo "show stat" | nc -U %s '
        '| egrep "(^#|%s)" '
        '| cut -d "," -f 1,2,7,14,18,19,20,22-25,27-29,33,37-39,56,57'
        '| sed -e "s/,/\t/g"'
        % (stat, sub_resource)
    )


@utils.reg_with_sub_resource
def register_haproxy_stat():
    return [
        ('-stat', {'help': "haproxy stat file path"})]


@utils.run_cmds
def list_port(**kwargs):
    debug = kwargs['debug'] and ' --debug ' or ' '
    base = "neutron" + debug + "port-list"
    host = kwargs['host'] and '--binding:host_id=%s' % kwargs['host'] or ''
    net = kwargs['net'] and '--network_id=%s' % kwargs['net'] or ''
    snet = kwargs['snet'] and 'subnet_id=%s' % kwargs['snet'] or ''
    ip = kwargs['ip'] and 'ip_address=%s' % kwargs['ip'] or ''
    fixed_ip = ' '.join([i for i in (snet, ip) if i])
    fixed_ip = '--fixed_ips %s' % fixed_ip if fixed_ip else ''
    device = kwargs['device'] and '--device_id=%s' % kwargs['device'] or ''
    owner = kwargs['owner']
    if owner:
        if owner in const.DEVICE_OWNERS:
            owner = '--device_owner=%s' % const.DEVICE_OWNERS[owner]
        else:
            raise utils.InnerException(
                'Unknown device_owner. Support list: %r' % (
                    const.DEVICE_OWNERS))
    ret = ' '.join([
        i for i in (base, host, net, fixed_ip, device, owner) if i])
    if base == ret:
        raise utils.InnerException(
            'ERROR: arguments missed, try use -h to find them')
    return ret


def register_port():
    return [
        ('-host', {'help': "ID of host which port is on"}),
        ('-net', {'help': "ID of network which port is on"}),
        ('-snet', {'help': "ID of subnet which port is on"}),
        ('-ip', {'help': "IP of port"}),
        ('-device', {'help': "ID of device which port belongs to"}),
        ('-owner', {'help': "Type of owner which port belongs to"}),
        ('-debug', {'action': 'store_true'})]


@utils.run_cmds
def list_sg_rule(**kwargs):
    base = "neutron security-group-rule-list"
    if kwargs['sg'] is None:
        raise utils.InnerException(
            'ERROR: arguments missed, try use -h to find them')
    sg_id = kwargs['sg'] and '--security_group_id=%s' % kwargs['sg'] or ''
    return ' '.join([base, sg_id])


def register_sg_rule():
    return [
        ('-sg', {'help': "ID of security-group to filter"})]


@utils.run_cmds
def list_ext_net(**kwargs):
    return "neutron net-list --router:external=True"


def register_ext_net():
    pass


@utils.run_cmds
def list_listener(**kwargs):
    base = "neutron lbaas-listener-list"
    if kwargs['lb'] is None:
        raise utils.InnerException(
            'ERROR: arguments missed, try use -h to find them')
    lb_id = kwargs['lb'] and '--loadbalancer_id=%s' % kwargs['lb'] or ''
    return ' '.join([base, lb_id])


def register_listener():
    return [
        ('-lb', {'help': "ID of lbaas-loadbalancer to filter"})]


@utils.run_cmds
def list_pool(**kwargs):
    base = "neutron lbaas-pool-list"
    if kwargs['lb'] is None:
        raise utils.InnerException(
            'ERROR: arguments missed, try use -h to find them')
    lb_id = kwargs['lb'] and '--loadbalancer_id=%s' % kwargs['lb'] or ''
    return ' '.join([base, lb_id])


def register_pool():
    return [
        ('-lb', {'help': "ID of lbaas-loadbalancer to filter"})]


@utils.run_cmds
def list_hm(**kwargs):
    base = "neutron lbaas-healthmonitor-list"
    if kwargs['lb'] is None:
        raise utils.InnerException(
            'ERROR: arguments missed, try use -h to find them')
    lb_id = kwargs['lb'] and '--loadbalancer_id=%s' % kwargs['lb'] or ''
    return ' '.join([base, lb_id])


def register_hm():
    return [
        ('-lb', {'help': "ID of lbaas-loadbalancer to filter"})]


@utils.dry
@utils.run_cmds
def list_siteconn(**kwargs):
    routers, ep_groups, conns, vpnsvcs, subnets = [
        {item['id']: item for item in api_cmd.get_resources(resc)}
        for resc in (
            'routers', 'vpn/endpoint-groups', 'vpn/ipsec-site-connections',
            'vpn/vpnservices', 'subnets')]

    ret = []
    for conn in conns.values():
        if kwargs['d']:
            if conn['status'] != 'DOWN':
                continue
        elif kwargs['a']:
            if conn['status'] != 'ACTIVE':
                continue
        elif kwargs['p']:
            if not conn['status'].startswith('PENDING'):
                continue
        vpnservice_id = conn['vpnservice_id']
        vpnservice = vpnsvcs[vpnservice_id]
        router = routers[vpnservice['router_id']]
        router_name = router['name']
        router_id = router['id']
        if kwargs['r'] and kwargs['r'] not in (router_name, router_id):
            continue
        local_address = router['external_gateway_info'].get(
            'external_fixed_ips')[0]['ip_address']
        local_epg_id = conn['local_ep_group_id']
        peer_epg_id = conn['peer_ep_group_id']
        local_epg = ep_groups[local_epg_id]
        if local_epg['type'] == 'subnet':
            local_epg = [subnets[e]['cidr'] for e in local_epg['endpoints']]
        else:
            local_epg = local_epg['endpoints']

        res = (
            "%(status)s: Left(%(local_epg)s) - %(local_ip)s -||- %(peer_ip)s "
            "- %(peer_id)s - Right(%(peer_epg)s)\n"
            "\tconnection: %(id)s(%(name)s)\n"
            "\tvpnservice: %(svc)s(%(svc_name)s)\n"
            "\trouter: %(router_id)s(%(router_name)s)\n") % {
                'name': conn['name'], 'id': conn['id'],
                'svc_name': vpnservice['name'], 'svc': vpnservice_id,
                'status': conn['status'],
                'peer_id': conn['peer_id'], 'peer_ip': conn['peer_address'],
                'router_name': router_name, 'router_id': router_id,
                'local_ip': local_address, 'local_epg': local_epg,
                'peer_epg': ep_groups[peer_epg_id]['endpoints']}
        ret.append(res)
    return ret


def register_siteconn():
    return [
        ('-a', {'help': 'Only dump Active site connections',
                'action': 'store_true'}),
        ('-d', {'help': 'Only dump Down site connections',
                'action': 'store_true'}),
        ('-p', {'help': 'Only dump PENDING site connections',
                'action': 'store_true'}),
        ('-r', {'help': 'Only dump site connections behind given router'})]


def list_portv2(**kwargs):
    if kwargs['id']:
        pass
    else:
        filters = {}
        if kwargs['owner']:
            if kwargs['owner'] in const.DEVICE_OWNERS:
                filters['device_owner'] = const.DEVICE_OWNERS[kwargs['owner']]
            else:
                raise utils.InnerException(
                    'Unknown device_owner. Support list: %r' % (
                        const.DEVICE_OWNERS))
        if kwargs['host']:
            filters['binding:host_id'] = kwargs['host']
        if kwargs['net']:
            filters['network_id'] = kwargs['net']
        if kwargs['snet']:
            filters['fixed_ips=subnet_id'] = kwargs['snet']
        if kwargs['ip']:
            filters['fixed_ips=ip_address'] = kwargs['ip']
        if kwargs['device']:
            filters['device_id'] = kwargs['device']
        data = api_cmd.get_resources('ports', filters)
        for d in data:
            for k in d:
                fmt = "{:<25} | {:<15}"
                print fmt.format(k, d[k])


def register_portv2():
    return [
        ('-host', {'help': "ID of host which port is on"}),
        ('-net', {'help': "ID of network which port is on"}),
        ('-snet', {'help': "ID of subnet which port is on"}),
        ('-ip', {'help': "IP of port"}),
        ('-device', {'help': "ID of device which port belongs to"}),
        ('-owner', {'help': "Type of owner which port belongs to"}),
        ('-id', {'help': 'Port ID, high priority to be used to query port'}),
        ('-detail', {'help': "Show port details", 'action': 'store_true'})]



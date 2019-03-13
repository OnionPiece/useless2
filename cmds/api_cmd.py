# writen by zongkai@polex.com.cn

import json
import os

import api_examples
import utils


curl_base = ("curl -s -g -H \"X-Auth-Token: %(token)s\" -X %(action)s "
             "http://%(api_ip)s:9696/v2.0/%(resource)s")


def create_resource(resource_name_or_alias, data, parent_id=None):
    resc_name = get_resource_map().get(
        resource_name_or_alias) or resource_name_or_alias
    if '%' in resc_name and parent_id:
        resc_name = resc_name % {'resc_id': parent_id}
    return json.loads(api(**{
        'resource': resc_name, 'action': 'create',
        'inner': True, 'data': json.dumps(data)})[0])


def update_resource(resource_name_or_alias, resc_id, data):
    resc_name = get_resource_map().get(
        resource_name_or_alias) or resource_name_or_alias
    if '%' in resc_name:
        resc_name = resc_name % {'resc_id': resc_id}
    return json.loads(api(**{
        'resource': resc_name, 'action': 'update', 'resc_id': resc_id,
        'inner': True, 'data': data})[0])


def delete_resource(resource_name_or_alias, resc_id):
    resc_name = get_resource_map().get(
        resource_name_or_alias) or resource_name_or_alias
    return api(**{
        'resource': resc_name, 'action': 'delete',
        'inner': True, 'id': resc_id})


def get_resource(resource_full_name, resc_id):
    resc_key = resource_full_name.split('/')[-1].replace('-', '_')[:-1]
    return json.loads(api(**{
        'resource': resource_full_name, 'action': 'show',
        'inner': True, 'id': resc_id})[0])[resc_key]


def get_resources(resource_full_name, filters=None):
    resc_key = resource_full_name.split('/')[-1].replace('-', '_')
    return json.loads(api(**{
        'resource': resource_full_name, 'action': 'list',
        'inner': True, 'filters': filters})[0])[resc_key]


def get_resource_map():
    return {
        "net": "networks",
        "snet": "subnets",
        "port": "ports",
        "fip": "floatingips",
        "router": "routers",
        "router_host": "routers/%(resc_id)s/l3-agents",
        "rm_router_intf": "routers/%(resc_id)s/remove_router_interface",
        "add_router_intf": "routers/%(resc_id)s/add_router_interface",
        "fw": "fw/firewalls",
        "fwp": "fw/firewall-policies",
        "fwr": "fw/firewall-rules",
        "sg": "security-groups",
        "sgr": "security-group-rules",
        "ike": "vpn/ikepolicies",
        "ipsec": "vpn/ipsecpolicies",
        "epg": "vpn/endpoint-groups",
        "vpn": "vpn/vpnservices",
        "lst": "lbaas/listeners",
        "pl": "lbaas/pools",
        "lb": "lbaas/loadbalancers",
        "hm": "lbaas/healthmonitors",
        "mem": "lbaas/pools/%(resc_id)s/members",
        "subnetpool": "subnetpools",
        "ipsec-siteconn": "vpn/ipsec-site-connections",
    }


def api_examples_help(**kwargs):
    action = kwargs['action']
    if action not in ('create', 'update'):
        raise utils.InnerException(
            'Show example (-e) and list attributes (-l) '
            'only work for create and update action')
    action = {'create': 'post', 'update': 'put'}[action]
    resource = kwargs['resource'].replace('-', '_')
    if kwargs['list']:
        for k, v in api_examples.get_attrs(resource, action).items():
            print "%s\t\t%s" % (k, v)
    if kwargs['example']:
        data = str(
            api_examples.get_example(resource, action)).replace(
                "'", '"')
        kwargs.update({
            'action': action.upper(), 'api_ip': 'localhost',
            'token': 'TOKEN', 'data': data})
        curl = (curl_base + ".json -d '%(data)s'") % kwargs
        print curl


def _get_ids_by_name(**kwargs):
    kwargs.update({'action': 'GET'})
    orig_resc = None
    if '%' in kwargs['resource']:
        orig_resc = kwargs['resource']
        kwargs['resource'] = orig_resc.split('/')[0]
    curl = (curl_base + ".json?name=%(name)s") % kwargs
    _resource_name = kwargs['resource'].split('/')[-1]
    if orig_resc:
        kwargs['resource'] = orig_resc
    return [
        obj['id'] for obj in json.loads(os.popen(curl).read())[_resource_name]]


def _get_ids(**kwargs):
    resc_id = kwargs.get('id')
    if resc_id:
        return [resc_id]
    name = kwargs.get('name')
    if not name:
        raise utils.InnerException('Neither resource id nor name is passed.')
    ids = _get_ids_by_name(**kwargs)
    if not ids:
        raise utils.InnerException('No resource found with give name')
    return ids


@utils.run_cmds
def create_or_update(**kwargs):
    data = kwargs.get('data')
    if not data:
        data_body = json.dumps({i[0]: i[1] for i in kwargs['attrs']})
        resc = kwargs['resource'].split('/')[-1][:-1]
        data = '{"%s": "%s"}' % (resc, data_body)
    kwargs['data'] = data
    curl = (curl_base + ".json -d '%(data)s'") % kwargs
    if kwargs.get('output') != "raw":
        curl += " | python -mjson.tool"
    return curl


def create_api(**kwargs):
    kwargs['action'] = 'POST'
    return create_or_update(**kwargs)


def update_api(**kwargs):
    kwargs['action'] = 'PUT'
    return create_or_update(**kwargs)


@utils.run_cmds
def list_api(**kwargs):
    kwargs.update({'action': 'GET'})
    if kwargs.get('filters'):
        filters = '&'.join(
            ['%s=%s' % (k, v) for (k, v) in kwargs['filters'].items()])
        kwargs.update({'filters': filters})
        curl = (curl_base.replace('http', "'http") + ".json?%(filters)s'"
                ) % kwargs
    else:
        curl = (curl_base + '.json') % kwargs
    if kwargs.get('output') != "raw":
        curl += " | python -mjson.tool"
    return curl


@utils.run_cmds
def show_api(**kwargs):
    kwargs.update({'action': 'GET'})
    resc_ids = _get_ids(**kwargs)
    if '%' in kwargs['resource']:
        curl = curl_base.replace('%(resource)s', kwargs['resource']) + '.json'
    else:
        curl = curl_base + '/%(resc_id)s.json'
    if kwargs.get('output') != "raw":
        curl += " | python -mjson.tool"
    ret = []
    for id in resc_ids:
        kwargs.update({'resc_id': id})
        ret.append(curl % kwargs)
    return ret


@utils.run_cmds
def delete_api(**kwargs):
    kwargs.update({'action': 'DELETE'})
    resc_ids = _get_ids(**kwargs)
    if len(resc_ids) > 1 and not kwargs.get('force', False):
        raise utils.InnerException(
            'Multiple resources found by given name, use -f to force delete')
    curl = curl_base + '/%(resc_id)s.json'
    ret = []
    for id in resc_ids:
        kwargs.update({'resc_id': id})
        ret.append(curl % kwargs)
    return ret


@utils.env_api_ip
@utils.env_token
def api(**kwargs):
    token = kwargs.get('token') or kwargs['env_token']
    if not token:
        raise utils.InnerException(
            'ERROR: The api command need X-Auth-Token, use -t to assign or '
            'set OCEANA_OS_TOKEN to use it.\n'
            'We cannot get token automatically by openstackclient, since it '
            'is not installed, or we have no permission to run it.')
    api_ip = kwargs.get('server_ip') or kwargs['env_api_ip']
    if not api_ip:
        raise utils.InnerException(
            'ERROR: The api command need API service IP, use -s to assign or '
            ' set OCEANA_OS_API_IP to use it')
    kwargs.update({'token': token, 'api_ip': api_ip})
    action = kwargs['action']
    return getattr(os.sys.modules[__name__], action + '_api')(**kwargs)


def arg_register(method_subparsers):
    api_subparser = method_subparsers.add_parser('api')
    sub_cmd_subparser = api_subparser.add_subparsers(dest='resource')
    for sub_resource in get_resource_map():
        action_parser = sub_cmd_subparser.add_parser(sub_resource)
        action_parser.add_argument(
            'action',
            choices=['create', 'list', 'show', 'delete', 'update'])
        action_parser.add_argument(
            '-name', help="Name of resource to show, delete, update")
        action_parser.add_argument(
            '-id', help="ID of resource to show, delete, update")
        action_parser.add_argument('-token', help="X-Auth-Token used to curl")
        action_parser.add_argument('-server-ip', help="IP of API server")
        action_parser.add_argument(
            '-force', action='store_true', help="Force to delete.")
        action_parser.add_argument(
            '-attr', action='append',
            type=lambda kv: kv.split("="), dest='attrs',
            metavar="-a KEY1=VAL1 -a KEY2=VAL2...",
            help="Attributes dict used for POST and PUT")
        action_parser.add_argument(
            '-example', action='store_true',
            help="Output data example used for POST and PUT")
        action_parser.add_argument(
            '-inner', action='store_true', default=False,
            help="Oceana inner using way")
        action_parser.add_argument(
            '-list', action='store_true',
            help="List resource attributes used for POST and PUT")
        action_parser.add_argument(
            '-output', choices=['json', 'raw'],
            help="Output format, default is formatted by python mjson.tool")


def main(**kwargs):
    kwargs.update({'resource': get_resource_map()[kwargs['resource']]})
    if kwargs['example'] or kwargs['list']:
        api_examples_help(**kwargs)
    else:
        api(**kwargs)

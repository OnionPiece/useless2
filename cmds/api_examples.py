# writen by zongkai@polex.com.cn

import sys

try:
    from neutron.api.v2 import attributes as n_attr
    from neutron.extensions import l3
    from neutron_fwaas.extensions import firewall
    from neutron_lbaas.extensions import loadbalancerv2
    from neutron_vpnaas.extensions import vpnaas
    from neutron_vpnaas.extensions import vpn_endpoint_groups
except:
    print 'Failed to import neutron modules, %s may fail to work' % __name__


common_attrs = [
    'description', 'admin_state_up', 'tenant_id'
]
special_default_attrs = [
    'router:external', 'external_gateway_info', 'floating_ip_address',
]
validate_revert_map = {
    'string': 'string_max_len=',
    'values': 'values_in:',
    'connection_limit': 'connection_limit>=',
    'range': 'range_in:',
    'regex_or_none': 'regex_or_none:',
}
validate_extend_list = [
    'dict_or_nodata',
]


def get_attr_name_and_map(resource):
    if resource.startswith('lbaas'):
        return resource[6:], loadbalancerv2.RESOURCE_ATTRIBUTE_MAP.get(
            resource[6:])
    elif resource.startswith('vpn'):
        resc = resource[4:]
        return resc, vpnaas.RESOURCE_ATTRIBUTE_MAP.get(
            resc) or vpn_endpoint_groups.RESOURCE_ATTRIBUTE_MAP.get(resc)
    elif resource in ('networks', 'ports', 'subnets', 'subnetpools'):
        return resource, n_attr.RESOURCE_ATTRIBUTE_MAP.get(resource)
    elif resource in ('routers', 'floatingips'):
        return resource, l3.RESOURCE_ATTRIBUTE_MAP.get(resource)


def get_attr_details(attr_map, action):
    ret = {}
    for attr, detail in attr_map.items():
        if not detail['allow_' + action]:
            continue
        val = ''
        if 'validate' in detail:
            val = detail['validate'].keys()[0].split(':')[1]
            val_var = detail['validate'].values()[0]
            if (val_var and val in validate_revert_map or
                    val in validate_extend_list):
                val = validate_revert_map[val] + str(val_var)
        if 'default' in detail:
            if detail['default'] in (n_attr.ATTR_NOT_SPECIFIED, ''):
                def_var = 'None'
            else:
                def_var = str(detail['default'])
            val += ',default:' + def_var
        ret[attr] = val
    return ret


def get_attrs(resource, action):
    attr_name, attr_map = get_attr_name_and_map(resource)
    return get_attr_details(attr_map, action)


def get_example(resource, action):
    attr_name, attr_map = get_attr_name_and_map(resource)
    ret = {}
    for attr, detail in attr_map.items():
        if attr in common_attrs:
            continue
        if not detail['allow_' + action]:
            continue
        val = ''
        if (detail.get('default', '\x01') is None and
                attr not in special_default_attrs):
            continue
        if 'validate' in detail:
            val = detail['validate'].keys()[0].split(':')[1]
            val_var = detail['validate'].values()[0]
            if val_var:
                if val in validate_revert_map:
                    val = validate_revert_map[val] + str(val_var)
                elif val in validate_extend_list:
                    val = {
                        k: v for (k, d) in val_var.items()
                        for v in d if v.startswith('type')}
        ret[attr] = val
    ret['name'] = "NAME"
    return {attr_name[:-1]: ret}

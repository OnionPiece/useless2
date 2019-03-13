# writen by zongkai@polex.com.cn

import netaddr as na
import netifaces as ni
import re
import subprocess

import utils


#inport_triage
drop_v6 = "table=0,priority=10,ipv6,actions=drop"
tun_match = "table=0,priority=2,in_port=%(tun_ofp)s,actions=resubmit(,1)"
local_match = (
    "table=0,priority=2,in_port=local,actions=resubmit(,1),resubmit(,2)")
local_match1 = (
    "table=0,priority=2,in_port=local,actions=resubmit(,2)")
inner_match = "table=0,priority=1,actions=resubmit(,2)"

#ingress_traffic
in_to_inner = (
    "table=1,priority=2,in_port=local,actions=%(seg_id)soutput:%(inner_ofp)s")
in_to_inner_and_local = (
    "table=1,priority=1,actions=%(seg_id)soutput:%(inner_ofp)s,LOCAL")
in_to_local = "table=1,priority=1,actions=output:LOCAL"

#egress_traffic
to_local_ip = (
    "table=2,priority=10,ipv4,nw_tos=0,nw_dst=%(local_ip)s,"
    "actions=mod_nw_tos:%(local_tos)s,LOCAL")
to_tun_ip = (
    "table=2,priority=10,ipv4,nw_tos=0,nw_dst=%(tun_ip)s,"
    "actions=mod_nw_tos:%(local_tos)s,output:%(tun_ofp)s")
bcast_to_remote = (
    "table=2,priority=9,ipv4,nw_tos=0,"
    "actions=mod_nw_tos:%(local_tos)s,%(tun_ofps)s")
reply_remote = (
    "table=2,priority=8,ipv4,nw_tos=%(tun_tos)s,"
    "actions=mod_nw_tos:%(local_tos)s,output:%(tun_ofp)s")
arp_to_local_ip = (
    "table=2,priority=7,arp,in_port=%(inner_ofp)s,arp_tpa=%(local_ip)s,"
    "actions=LOCAL")
arp_to_tun_ip = (
    "table=2,priority=7,arp,in_port=%(inner_ofp)s,arp_tpa=%(tun_ip)s,"
    "actions=output:%(tun_ofp)s")
arp_bcast_from_inner = (
    "table=2,priority=6,arp,in_port=%(inner_ofp)s,"
    "actions=%(tun_ofps)s,LOCAL")
arp_bcast_from_local = (
    "table=2,priority=5,arp,in_port=LOCAL,"
    "actions=%(tun_ofps)s,%(seg_id)soutput:%(inner_ofp)s")
arp_bcast_from_local1 = (
    "table=2,priority=5,arp,in_port=LOCAL,"
    "actions=%(tun_ofps)s,%(seg_id)s")
default_drop = "table=2,priority=1,actions=drop"

net_node_flows = [
    drop_v6, tun_match, local_match, inner_match,
    in_to_inner_and_local, in_to_inner,
    to_local_ip, to_tun_ip, bcast_to_remote, reply_remote,
    arp_to_local_ip, arp_to_tun_ip,
    arp_bcast_from_inner, arp_bcast_from_local, default_drop,
]

other_node_flows= [
    drop_v6, tun_match, local_match1,
    in_to_local,
    bcast_to_remote, arp_bcast_from_local1, reply_remote,
]


def get_local_ip_info(dev):
    ip = ni.ifaddresses(dev)[2][0]['addr']
    try:
        prefix = na.IPAddress(
            ni.ifaddresses(dev)[2][0]['netmask']).netmask_bits()
    except AttributeError:
        prefix = na.IPAddress(
            ni.ifaddresses(dev)[2][0]['netmask']).bits().count('1')
    return ip, prefix


@utils.inner
@utils.run_cmds
def inner_call(**kwargs):
    return kwargs['cmd']


def is_net_node():
    def _get_ovs_brs(**kwargs):
        return 'ovs-vsctl list-br'
    return 'br-ex' in inner_call(**{'cmd': 'ovs-vsctl list-br'})[0]


def get_ovs_intf_ip(dev):
    return inner_call(**{
        'cmd': 'ovs-vsctl get interface %s options' % dev})[0].split('"')[5]


def get_br_node_ex_intf_info():
    pi = inner_call(**{
        'cmd': 'ovsdb-client dump Open_vSwitch Interface name ofport'})[0]
    intf_dict = {}
    inner_ofp = re.search(re.compile('"2-br-ex"\s+(\w+)'), pi)
    if is_net_node():
        if not inner_ofp:
            raise utils.InnerException(
                'Interface 2-br-ex not exists, try to rerun with -i and -p first.')
        intf_dict['inner'] = inner_ofp.groups()[0]
    for intf, ofp in re.findall(re.compile('"(\d+-\d+-\d+-\d+)"\s+(\d+)'), pi):
        intf_dict[intf.replace('-', '.')] = ofp
    if len(intf_dict) == 1:
        raise utils.InnerException(
            'No formatted interface found, try to rerun with -i and -p first.')
    return intf_dict


@utils.ignore_err
@utils.run_cmds
def set_local(**kwargs):
    dev = kwargs['i']
    dev_ip, dev_ip_prefix = get_local_ip_info(dev)
    cidr = na.IPNetwork('%s/%s' % (dev_ip, dev_ip_prefix)).cidr
    cidr_next = na.IPNetwork('%s/%s' % (dev_ip, dev_ip_prefix + 1)).next()
    ret = [
        'ovs-vsctl --may-exist add-br br-node-ex',
        'ip l set dev br-node-ex up',
        'ip a replace %s/%s dev br-node-ex' % (dev_ip, dev_ip_prefix),
        'ip r del %s dev br-node-ex' % cidr,
        'ip r replace %s dev br-node-ex' % cidr_next]
    if is_net_node():
        for (br, intf, peer) in [('br-ex', '2-node-ex', '2-br-ex'),
                                 ('br-node-ex', '2-br-ex', '2-node-ex')]:
            ret.append((
                'ovs-vsctl --may-exist add-port %(br)s %(intf)s -- '
                'set interface %(intf)s type=patch option:peer=%(peer)s') % {
                    'br': br, 'intf': intf, 'peer': peer})
    return ret


@utils.run_cmds
def set_peer(**kwargs):
    local_ip = get_local_ip_info(kwargs['i'])[0]
    return [
        ('ovs-vsctl --may-exist add-port br-node-ex %s -- set interface %s '
         'type=vxlan option:df_default="true" option:in_key=flow '
         'option:local_ip=%s option:out_key=flow option:remote_ip=%s') % (
            peer.replace('.', '-'), peer.replace('.', '-'), local_ip, peer)
            for peer in kwargs['p']]


@utils.run_cmds
def set_flows(**kwargs):
    seg_id = ''
    if kwargs['seg_id']:
        seg_id = 'mod_vlan_vid:%s,' % kwargs['seg_id']
    local_ip = get_local_ip_info('br-node-ex')[0]
    intf_dict = get_br_node_ex_intf_info()
    inner_ofp = intf_dict.pop('inner', None)
    tos_list = sorted(set(intf_dict.keys() + [local_ip]))
    intf_dict.pop(local_ip, None)
    flows = is_net_node() and net_node_flows or other_node_flows
    keys = {
        'inner_ofp': inner_ofp,
        'local_ip': local_ip,
        'local_tos': (tos_list.index(local_ip) + 1) * 4,
        'tun_ofps': ',output:'.join([''] + intf_dict.values())[1:]}
    to_set = []
    for flow in flows:
        if '%' not in flow:
            to_set.append(flow)
            continue
        if 'tun_ip' in flow or 'tun_ofp' in flow or 'tun_tos' in flow:
            for ip in intf_dict:
                keys.update({
                    'tun_ofp': intf_dict[ip],
                    'tun_tos': (tos_list.index(ip) + 1) * 4,
                    'tun_ip': ip,
                    'seg_id': seg_id})
                to_set.append(flow % keys)
        else:
            to_set.append(flow % keys)
    ret = ['ovs-ofctl add-flow br-node-ex "%s"' % flow for flow in to_set]
    ret.insert(0, 'ovs-ofctl del-flows br-node-ex')
    return ret


def build_fakenet(**kwargs):
    if kwargs['o']:
        set_flows(**kwargs)
    elif kwargs['i']:
        set_local(**kwargs)
        if kwargs['p']:
            for peer_ip in kwargs['p']:
                if not na.valid_ipv4(peer_ip):
                    raise utils.InnerException('Invalid peer IP %s' % peer_ip)
                reach = subprocess.Popen(
                    'ping -c1 -w1 %s -I %s ' % (peer_ip, kwargs['i']),
                    shell=True, stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT).wait() == 0
                if not reach:
                    raise utils.InnerException(
                        'Peer IP %s is unreachable from %s' % (
                            peer_ip, kwargs['i']))
            set_peer(**kwargs)
    else:
        raise utils.InnerException(
            'ERROR: arguments missed, try use -h to find them')


def register_fakenet():
    return [
        ('-i', {'help': 'Interface to build fake external, need with -p'}),
        ('-p', {'help': 'Peers(IP) to build fake external network with',
                'action': 'append'}),
        ('-o', {'help': 'Only reload flows on bridge ',
                'action': 'store_true'}),
        ('-seg-id', {'help': 'Fake external network segment id'}),
    ]

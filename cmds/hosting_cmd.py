# writen by zongkai@polex.com.cn

import utils


@utils.run_cmds
def hosting_mq_queue(sub_resource, **kwargs):
    base = (
        'rabbitmqctl list_queues --online pid name synchronised_slave_pids '
        '| egrep '
    )
    neutron = '"(lbaas|l3|dhcp|metering|q-agent|q-plugin|q-reports|ipsec)"'
    queues = {
        "nova": base + '"(cert|conductor|console|consoleauth| scheduler)"',
        "neutron": base + neutron,
        "cinder": base + 'cinder',
        "glance": base + 'notifications',
    }
    queue = queues.get(sub_resource)
    if not queue:
        raise utils.InnerException(
            'Unknown resource, or not supported yet...')
    return queue


@utils.run_cmds
def hosting_router(sub_resource, **kwargs):
    return [
        "neutron router-show %s | awk '/ id /{print $4}'" % sub_resource,
        "neutron l3-agent-list-hosting-router %s" % sub_resource,
        (
            "for i in `neutron router-port-list %s | "
            "awk '{if($4 == \"|\") print $2}'`; do "
            "neutron port-show $i | "
            "egrep \"(binding:host_id| id |device_owner|fixed_ips)\" ;"
            "echo \"\" ; done" % sub_resource
        ),
    ]


@utils.run_cmds
def hosting_net(sub_resource, **kwargs):
    return "neutron dhcp-agent-list-hosting-net %s" % sub_resource


@utils.run_cmds
def hosting_lb(sub_resource, **kwargs):
    return "neutron lbaas-agent-hosting-loadbalancer %s" % sub_resource


@utils.run_cmds
def hosting_active_router(**kwargs):
    return (
        'for i in `ip netns | grep qrouter`; do '
        'ip netns exec $i ip a | grep "ha-" -A 5 | grep -q "169.254.0.*/24"; '
        'if [[ $? -eq 0 ]]; then '
        #'echo $i | cut -c 9- '
        #'| xargs -I {} cat /var/lib/neutron/ha_confs/{}/keepalived.conf '
        #'| grep "instance VR"; '
        'echo $i; '
        'fi; '
        'done'
    )


def register_active_router(*args, **kwargs):
    # active_router doesn't need any arguments.
    pass


@utils.run_cmds
def hosting_active_siteconn(**kwargs):
    return (
        "for i in `ps -ef | awk '/ipsec\/pluto/{print $10}'`; do "
        "ipsec whack --status --ctlbase $i | "
        "awk -F '\"' '/IPsec SA established/{print $2}' | "
        "cut -d '/' -f 1; "
        " done | sort | uniq"
    )


def register_active_siteconn(*args, **kwargs):
    # active_siteconn doesn't need any arguments.
    pass

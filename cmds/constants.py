KNOWN_CMDS = [
    'neutron', 'echo', 'rabbitmqctl', 'curl',
]
TOKEN = 'OCEANA_OS_TOKEN'
API_IP = 'OCEANA_OS_API_IP'

DEVICE_OWNERS = {
    'nova': 'compute:nova',
    'compute': 'compute:None',
    'interface': 'network:router_interface',
    'gateway': 'network:router_gateway',
    'lbaas': 'neutron:LOADBALANCERV2',
    'dhcp': 'network:dhcp',
    'fip': 'network:floatingip',
}

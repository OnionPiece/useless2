import os

from neutron.agent.linux import tc_htb_lib

namespace = 'qrouter-7559b358-6cf4-4900-9c7d-99046bbad2db'
try:
    name = os.popen('ip netns exec %s ip a | grep ": qg-"' % namespace).read().split(':')[1].strip()
    gw_ip = os.popen('ip netns exec %s ip a show %s | grep " inet .*/24"' % (namespace, name)).read().strip().split()[1][:-3]
except:
    print 'fail to get gw dev name'
    os.sys.exit(1)
tc_cmd = tc_htb_lib.TcHTBCommand(name, namespace, 7, 3072, gw_ip)
print tc_cmd._get_u32_match_class_id_map()
print tc_cmd._get_class_id_from_ip('172.16.0.130')
print tc_cmd._get_class_id_from_ip('172.16.0.130/24')
print tc_cmd._get_class_id_from_ip('172.16.0.130/32')
print tc_cmd._get_class_id_from_ip('172.16.0.133/32')
try:
    print tc_cmd._get_class_id_from_ip('172.16.0.133/33')
except tc_htb_lib.InvalidInput as e:
    print e
print tc_cmd._get_class_id_from_ip('172.16.0.134')

def print_os():
    print 'os result:'
    for t,cmd in {'qdisc': 'ip netns exec %s tc qdisc show dev %s' % (namespace, name),
                  'class': 'ip netns exec %s tc class show dev %s' % (namespace, name),
                  'filter': 'ip netns exec %s tc filter show dev %s' % (namespace, name)}.items():
        print t
        for i in os.popen(cmd).readlines():
            print '\t', i.strip()

def print_resource(fip_ip, after_process=True):
    if after_process:
        print "after process..."
    print 'fip_ip', fip_ip
    class_id, exists = tc_cmd._get_class_id_from_ip(fip_ip)
    print "class_id=%s, exists=%r" % (class_id, exists)
    print tc_cmd._get_htb_class(class_id)
    print 'filter:', tc_cmd._get_htb_filters(class_id)
    print_os()
    print ""

def process_gw_default_bw(gw_kbit=None):
    if gw_kbit is not None:
        tc_cmd.set_htb_default_bw_limit(gw_kbit)
        print "after process...gw_kbit:", gw_kbit
    else:
        print "without process..."
    print tc_cmd._get_htb_class(2) # 2 is default class
    print 'filter:', tc_cmd._get_htb_filters(2)
    print_os()
    print ""

cleanup_cmd = 'ip netns exec %s tc qdisc delete dev %s root' % (namespace, name)
cleanup_cmd2 = 'ip netns exec %s tc qdisc delete dev %s ingress' % (namespace, name)
print "init ... cleanup with", cleanup_cmd
print "init ... cleanup with", cleanup_cmd2
os.system(cleanup_cmd)
os.system(cleanup_cmd2)
verify_cmd = 'ip netns exec %s tc qdisc show dev %s' % (namespace, name)
print "verify ... with", verify_cmd
print "\t", os.popen(verify_cmd).read()

fip_ip1 = '172.16.0.130'
fip_ip2 = '172.16.0.133'
print_resource(fip_ip1, False)
print_resource(fip_ip2, False)

fip1 = {
    'floating_ip_address': fip_ip1,
    'rate_limit_kbps': 5000,
}

fip2 = {
    'floating_ip_address': fip_ip2,
    'rate_limit_kbps': 10000,
}

print "set for 130..."
tc_cmd.set_htb_class_bw_limit(fip1)
print_resource(fip_ip1)

print "check gw default bw"
process_gw_default_bw()
print ""

print "set for 133..."
tc_cmd.set_htb_class_bw_limit(fip2)
print_resource(fip_ip2)

print "update for 130..."
fip1['rate_limit_kbps'] = 10000
tc_cmd.set_htb_class_bw_limit(fip1)
print_resource(fip_ip1)

print "unset for 130..."
fip1['rate_limit_kbps'] = 0
tc_cmd.set_htb_class_bw_limit(fip1)
print_resource(fip_ip1)

print "reset for 130..."
fip1['rate_limit_kbps'] = 3000
tc_cmd.set_htb_class_bw_limit(fip1)
print_resource(fip_ip1)

print "star to process gw default bw"
process_gw_default_bw()
process_gw_default_bw(2048)
process_gw_default_bw(10048)
process_gw_default_bw(0)
process_gw_default_bw(2048)
print "end of to process gw default bw"

print "check classid range..."
for ip in (fip2, fip1, fip2, fip1, fip2):
    tc_cmd.delete_htb_class_bw_limit('%s/32' % ip['floating_ip_address'])
    tc_cmd.set_htb_class_bw_limit(ip)
    print_resource(ip['floating_ip_address'])
print "end of check classid range"

print "delete for 130..."
tc_cmd.delete_htb_class_bw_limit('%s/32' % fip_ip1)
print_resource(fip_ip1)

OS_TOKEN=7c451b2b49d14433aa7ec7a64bc9c906
fwr1_id=`curl -g -X POST http://192.168.1.3:9696/v2.0/fw/firewall_rules.json -H "X-Auth-Token: $OS_TOKEN" -d '{"firewall_rule": {"source_port": "22", "action": "allow", "protocol": "tcp", "name": "tcp22allow", "ip_version": 4}}' | python -mjson.tool | awk -F'"' '/"id"/{print $4}'`

fwr2_id=`curl -g -X POST http://192.168.1.3:9696/v2.0/fw/firewall_rules.json -H "X-Auth-Token: $OS_TOKEN" -d '{"firewall_rule": {"source_port": "80", "action": "allow", "protocol": "tcp", "name": "tcp80allow", "ip_version": 4}}' | python -mjson.tool | awk -F'"' '/"id"/{print $4}'`

fwr3_id=`curl -g -X POST http://192.168.1.3:9696/v2.0/fw/firewall_rules.json -H "X-Auth-Token: $OS_TOKEN" -d '{"firewall_rule": {"action": "allow", "ip_version": 4, "protocol": "icmp", "name": "icmpallow"}}' | python -mjson.tool | awk -F'"' '/"id"/{print $4}'`

fwp_id=`curl -g -X POST http://192.168.1.3:9696/v2.0/fw/firewall_policies.json -H "X-Auth-Token: $OS_TOKEN" -d '{"firewall_policy": {"name": "fwp", "firewall_rules": ["'$fwr1_id'", "'$fwr2_id'", "'$fwr3_id'"]}}' | python -mjson.tool | awk -F'"' '/"id"/{print $4}'`

curl -g -X POST http://192.168.1.3:9696/v2.0/fw/firewalls.json -H "X-Auth-Token: $OS_TOKEN" -d '{"firewall": {"router_ids": ["8bdd8dc1-5a10-46d4-9498-5ef96131ed62"], "admin_state_up": true, "firewall_policy_id": "'$fwp_id'", "name": "fw"}}'

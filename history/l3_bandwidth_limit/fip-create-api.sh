curl -g -i -X POST http://192.168.1.3:9696/v2.0/floatingips.json -H "X-Auth-Token: $OCEANA_OS_TOKEN" \
-d '{"floatingip": {
"floating_network_id": "1a2d69c2-ff83-40c8-9ae0-4c3227346c3e",
"rate_limit": 1024
}}'

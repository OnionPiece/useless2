router_id=2963f629-fba6-4f17-ac16-d40a9c96dd15
curl -s -g -i -X PUT http://192.168.1.3:9696/v2.0/routers/${router_id}.json -H "X-Auth-Token: $OCEANA_OS_TOKEN" \
-d '{"router": {
"rate_limit_kbps": 1072
}}'

#"external_gateway_info": {},
#"external_gateway_info": {"network_id": "1a2d69c2-ff83-40c8-9ae0-4c3227346c3e"}

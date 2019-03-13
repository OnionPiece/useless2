curl -s -g -i -X PUT http://192.168.1.3:9696/v2.0/routers.json -H "X-Auth-Token: $OCEANA_OS_TOKEN" \
-d '{"router": {
"name": "routertest",
"rate_limit_kbps": 1072,
"external_gateway_info": {"network_id": "d777f955-94ed-469d-a99e-1549c10826e9"}
}}'

#"external_gateway_info": {},

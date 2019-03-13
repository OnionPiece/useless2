curl -s -g -i -X PUT http://192.168.1.3:9696/v2.0/routers/7559b358-6cf4-4900-9c7d-99046bbad2db.json -H "X-Auth-Token: $OCEANA_OS_TOKEN" \
-d '{"router": {
"external_gateway_info": {"network_id": "1a2d69c2-ff83-40c8-9ae0-4c3227346c3e"}
}}'

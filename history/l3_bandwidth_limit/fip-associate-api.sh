curl -g -i -X PUT http://192.168.1.3:9696/v2.0/floatingips/24cf0475-ecd9-4b63-90ae-7ee165b0747a.json -H "X-Auth-Token: $OCEANA_OS_TOKEN" \
-d '{"floatingip": {
"port_id": "f02521bf-cdce-459a-96f4-236bd11306e8"
}}'

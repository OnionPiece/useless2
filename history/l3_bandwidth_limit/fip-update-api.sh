fip=8eeb4b43-c1f3-4fd3-9974-6e1965ccb1ab
curl -g -i -X PUT http://192.168.1.3:9696/v2.0/floatingips/${fip}.json -H "X-Auth-Token: $OCEANA_OS_TOKEN" \
-d '{"floatingip": {
"rate_limit_kbps": 3072
}}'

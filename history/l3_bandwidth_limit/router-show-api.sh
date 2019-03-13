curl -s -g -X GET http://192.168.1.3:9696/v2.0/routers/7559b358-6cf4-4900-9c7d-99046bbad2db.json -H "X-Auth-Token: $OCEANA_OS_TOKEN" | python -mjson.tool

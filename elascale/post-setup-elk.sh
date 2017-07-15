#!/bin/bash
FILE_DIR=$(cd $(dirname "$0") && pwd)

VMS=`docker-machine ls | grep Running | awk '{print $1}'`
SWARM_MASTER_HOSTNAME=`echo "${VMS}" | grep master`
SWARM_MASTER=`docker-machine ip ${SWARM_MASTER_HOSTNAME}`

# Wait for port 9200 to be up and open
while ! nc -z -w 1 ${SWARM_MASTER} 9200; do
    sleep 1
done

# Sleep 60 more seconds, just in case
sleep 60

curl -s -H 'Content-Type: application/json' -XPUT "http://${SWARM_MASTER}:9200/_template/metricbeat" -d@${FILE_DIR}/beats/metricbeat/metricbeat.template.json
curl -s -H 'Content-Type: application/json' -XPUT "http://${SWARM_MASTER}:9200/_template/dockbeat" -d@${FILE_DIR}/beats/dockbeat/dockbeat.template.json

/home/ubuntu/node_modules/elasticdump/bin/elasticdump --input=${FILE_DIR}/json_files/my_index_analyzer.json --output=http://${SWARM_MASTER}:9200/.kibana --type=analyzer
/home/ubuntu/node_modules/elasticdump/bin/elasticdump --input=${FILE_DIR}/json_files/my_index_mapping.json --output=http://${SWARM_MASTER}:9200/.kibana --type=mapping
/home/ubuntu/node_modules/elasticdump/bin/elasticdump --input=${FILE_DIR}/json_files/my_index_data.json --output=http://${SWARM_MASTER}:9200/.kibana --type=data


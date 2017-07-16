#!/bin/bash
FILE_DIR=$(cd $(dirname "$0") && pwd)

echo "Getting host information ..."
VMS=`docker-machine ls | grep Running | awk '{print $1}'`
SWARM_AGG_HOSTNAME=`echo "${VMS}" | grep agg`
SWARM_AGG=`docker-machine ip ${SWARM_AGG_HOSTNAME}`

SWARM_WORKER_HOSTNAME=`echo "${VMS}" | grep worker`
SWARM_WORKER=`docker-machine ip ${SWARM_WORKER_HOSTNAME}`

CORE_DB_HOSTNAME=`echo "${VMS}" | grep db`
CORE_DB=`docker-machine ip ${CORE_DB_HOSTNAME}`

echo "${SWARM_AGG_HOSTNAME} is at ${SWARM_AGG}"
echo "${SWARM_WORKER_HOSTNAME} is at ${SWARM_WORKER}"
echo "${CORE_DB_HOSTNAME} is at ${CORE_DB}"
echo

# SCP docker-compose file over to swarm-maser
echo "Copying docker-compose file..."
docker-machine scp ${FILE_DIR}/iot_app/docker-compose.yml swarm-master:~/iot-app-docker-compose.yml

# Update SWARM_AGG_HOSTNAME and SWARM_AGG placeholders in .yml file
docker-machine ssh swarm-master sed -i s/CORE_DB_HOSTNAME/${CORE_DB_HOSTNAME}/g iot-app-docker-compose.yml
docker-machine ssh swarm-master sed -i s/SWARM_AGG_HOSTNAME/${SWARM_AGG_HOSTNAME}/g iot-app-docker-compose.yml
docker-machine ssh swarm-master sed -i s/SWARM_AGG/${SWARM_AGG}/g iot-app-docker-compose.yml

# Deploy the stack
echo "Deploying iot-app stack..."
docker-machine ssh swarm-master sudo docker stack deploy -c iot-app-docker-compose.yml iot_app

echo -e "\nDeployed Kafka and Zookeeper...  Deploying sensors to the aggregator..."

docker-machine ssh swarm-master sudo docker service create --detach=true --replicas 1 --name iot_sensor --constraint node.hostname==${SWARM_AGG_HOSTNAME} perplexedgamer/sensor:v2 ${SWARM_AGG} 9092
docker-machine ssh swarm-master sudo docker service create --detach=true --replicas 1 --name iot_edge_processor --constraint node.Hostname==${SWARM_WORKER_HOSTNAME} perplexedgamer/edge_processor:v3 ${SWARM_AGG} ${CORE_DB}

echo -e "\nDeployed sensors, processors, and Cassandra; IoT Application deployment complete!"

echo -e "Current services status:\n"
docker-machine ssh swarm-master sudo docker service ls


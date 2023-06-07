#!/bin/bash
set -e

#KJB JOB TO RUN
JOB_NAME=${JOB_NAME:-null}
JOB_PARAMS=${JOB_PARAMS:-null}
DB_USER=${DB_USER:-postgres}
DB_DATABASE=${DB_DATABASE:-postgres}
DB_PASS=${DB_PASS:-password}
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
PENTAHO_ADMIN_USER=${PENTAHO_ADMIN_USER:-admin}
PENTAHO_ADMIN_PASS=${PENTAHO_ADMIN_PASS:-password}
PENTAHO_SERVER=${PENTAHO_SERVER:-pentaho}
PENTAHO_PORT=${PENTAHO_PORT:-8080}
RANGE=${RANGE:-200000}
MINUTES_GAP=${MINUTES_GAP:-10}
COPIES_READ=${COPIES_READ:-2}
COPIES_WRITE=${COPIES_WRITE:-2}
ENCRIPTION=${ENCRIPTION:-N}

function config_pentahoPDI(){
	echo "Configuring PentahoPDI"
	sed -i "s/org.apache.xerces.jaxp,org.apache.xerces.jaxp.validation,org.apache.xerces.dom/org.apache.xerces.jaxp,org.apache.xerces.jaxp.validation,org.apache.xerces.dom,javax.crypto,javax.crypto.*/g" /pentahoetl/data-integration/system/karaf/etc/config.properties
}

function config_etls(){
	echo "Configuring ETLs jobs and transformations"
	echo -e "IP_BAME=${DB_HOST}
DATABASE_BAME=${DB_DATABASE}
PORT_BAME=${DB_PORT}
USER_BAME=${DB_USER}
PASSWORD_BAME=${DB_PASS}
ADMIN_USER=${PENTAHO_ADMIN_USER}
ADMIN_PASSWORD=${PENTAHO_ADMIN_PASS}
URL_PENTAHO=${PENTAHO_SERVER}:${PENTAHO_PORT}
RANGE=${RANGE}
MINUTES_GAP=${MINUTES_GAP}
COPIES_READ=${COPIES_READ}
COPIES_WRITE=${COPIES_WRITE}
ENCRIPTION=${ENCRIPTION:-N}" > /pentahoetl/90.PDI_Loaders/${JOB_NAME}/configuration.properties
	cat /pentahoetl/90.PDI_Loaders/${JOB_NAME}/configuration.properties
}

function execute_etl(){
	mkdir -p /pentahoetl/90.PDI_Loaders/${JOB_NAME}/logs
	echo "Starting JOB: ${JOB_NAME}, with params: ${JOB_PARAMS}"
	sh /pentahoetl/data-integration/kitchen.sh -param:dir="/pentahoetl/90.PDI_Loaders/${JOB_NAME}" -file:"/pentahoetl/90.PDI_Loaders/${JOB_NAME}/${JOB_NAME}_v1.kjb" -log:"/pentahoetl/90.PDI_Loaders/${JOB_NAME}/logs/${JOB_NAME}_v1.kjb.log" ${JOB_PARAMS}
}

if [ "$1" = 'run' ]; then
  config_pentahoPDI
  config_etls
  execute_etl
else
  exec "$@"
fi
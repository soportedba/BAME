#!/usr/bin/env bash

declare -A arr
declare -A hosts

AUTO=$2

function read_properties(){
if [ -f "$1" ]
then
	# declare an associative array
	# read file line by line and populate the array. Field separator is "="
	while IFS='=' read -r k v; do
	arr["$k"]=`echo "$v"|sed 's/\r//'`
	#echo "$k" ${arr["$k"]} 
	done < "$1"
	# Additional properties
	PROP=`readlink -f $1`
	arr["ba.deploy.files"]=`dirname $PROP`
	arr["memtotal"]=`awk '/MemTotal/ {print $2}' /proc/meminfo`
	arr["totalcores"]=`cat /proc/cpuinfo | grep processor | wc -l`
	
	echo ""
	echo ""
	echo "PARAMETERS REVIEW. List of important deployment parameters."
	echo ""
	echo "ba.pentahoba.prj.description = ${arr["ba.pentahoba.prj.description"]}"
	echo "ba.pentahoba.deploy.dir = ${arr["ba.pentahoba.deploy.dir"]}"
	echo "ba.pentahoba.server = ${arr["ba.pentahoba.server"]}"
	echo "postgre.prj.ip = ${arr["postgre.prj.ip"]}"
	echo "postgre.prj.database = ${arr["postgre.prj.database"]}"
	echo ""
	echo "Review all parameters carefully before continue execution!!!, ENTER to continue, Ctrl+C to cancel"	
	if [ "$AUTO.a" = "Y.a" ];
	then
		echo "Automatic deployment!!!"	
	else
		read sure
	fi
else
  echo "ERROR: .properties file "$1" not found."
  exit 0
fi
}

function publish_pentahoBA(){
	DB_SUFFIX=`echo ${arr["postgre.prj.database"]}|tr '/a-z/' '/A-Z/'`
	DB_ROLE_SUFFIX=`echo ${arr["postgre.prj.database"]}|tr '/a-z/' '/A-Z/'|sed "s/_DWH//g"`
	
	# CHANGE default admin password
	curl http://admin:password@${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/api/userroledao/user \
		-X PUT \
		-H 'Content-Type: application/json' \
		-d '{"userName":"admin", "newPassword":"'${arr["ba.pentahoba.password"]}'", "oldPassword":"password"}' 

	# Pentaho specific role with format: role<DB_ROLE_SUFFIX>
	curl http://admin:${arr["ba.pentahoba.password"]}@${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/api/userroledao/createRole?roleName=role${DB_ROLE_SUFFIX} -X PUT
	
	# Pentaho assign specific roles to admin
	curl http://admin:${arr["ba.pentahoba.password"]}@${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/api/userroledao/assignRoleToUser?userName=admin\&roleNames=role${DB_ROLE_SUFFIX} -X PUT

	# Register {prj}_DWH jndi datasource (uppercase)
	curl http://admin:${arr["ba.pentahoba.password"]}@${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/plugin/data-access/api/datasource/jdbc/connection/${DB_SUFFIX} \
		-X PUT \
		-H 'Content-Type: application/json' \
		-d '{"changed": true,"usingConnectionPool": true,"connectSql": "","databaseName": "'${arr["postgre.prj.database"]}'","databasePort": "'${arr["postgre.prj.port"]}'","hostname": "'${arr["postgre.prj.ip"]}'","name": "'${DB_SUFFIX}'","password": "'${arr["postgre.prj.password"]}'","username": "'${arr["postgre.prj.username"]}'","attributes": {},"connectionPoolingProperties": {},"extraOptions": {},"accessType": "NATIVE","databaseType": {"defaultDatabasePort": '${arr["postgre.prj.port"]}',"extraOptionsHelpUrl": "http://jdbc.postgresql.org/documentation/83/connect.html#connection-parameters","name": "PostgreSQL","shortName": "POSTGRESQL","supportedAccessTypes": ["NATIVE","ODBC","JNDI"]}}'

	# Will get all prpt, cda, cdfde, wcdf, xwarq, saiku, xjpivot files
	for j in `find ${arr["ba.deploy.files"]}/100.Publications -type f -name "*.zip"`
	do
		${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/import-export.sh --import --url=http://${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho --username=${arr["ba.pentahoba.admin"]} --password=${arr["ba.pentahoba.password"]} --charset=UTF-8 --path=/public --file-path=$j --overwrite=true --permission=true --retainOwnership=true
	done
	# XMI datasources registration
	# Domain_id is indicated by upper(postgre.prj.database)
	for j in `find ${arr["ba.deploy.files"]}/100.Publications -type f -name "*.xmi"`
	do
		# Generating temporary upload file
		tmp_upload_domain=${DB_SUFFIX}
		tmp_upload_name=$tmp_upload_domain.tmp.xmi
		# API call to upload xmi file
		curl -v -H "Content-Type: multipart/form-data" -X PUT -F metadataFile=@$j -F overwrite=true -F domainId=$tmp_upload_domain -u admin:${arr["ba.pentahoba.password"]} http://${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/plugin/data-access/api/datasource/metadata/domain/$tmp_upload_domain
	done
	
	# XML analysis datasources registration
	# 
	for j in `find ${arr["ba.deploy.files"]}/100.Publications -type f -name "*.xml"|grep -v exportManifest`
	do
		# Generating temporary upload file
		DS=${DB_SUFFIX}
		tmp_ds=${DS}
		tmp_catalog=${arr["ba.pentahoba.prj.description"]}_Analytics
		# API call to upload xml file
		curl -v -H "Content-Type: multipart/form-data" -X PUT -F uploadInput=@$j -F overwrite=true -F xmlaEnabledFlag=true -F parameters="DynamicSchemaProcessor=com.mysample.mondrian.dsp.DynamicSchemaProcessor;Datasource=$tmp_ds" -u admin:${arr["ba.pentahoba.password"]} http://${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/plugin/data-access/api/datasource/analysis/catalog/$tmp_catalog
	done
	
	# Pentaho BA refresh
	# Launch command in nohup to wait for Pentaho to be available
	curl http://admin:${arr["ba.pentahoba.password"]}@${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/api/system/refresh/globalActions
	curl http://admin:${arr["ba.pentahoba.password"]}@${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/api/system/refresh/systemSettings
	curl http://admin:${arr["ba.pentahoba.password"]}@${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/api/system/refresh/metadata
	curl http://admin:${arr["ba.pentahoba.password"]}@${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/plugin/saiku/api/admin/discover/refresh
	curl http://admin:${arr["ba.pentahoba.password"]}@${arr["ba.pentahoba.server"]}:${arr["ba.pentahoba.port"]}/pentaho/api/system/refresh/mondrianSchemaCache
}

read_properties $1
publish_pentahoBA

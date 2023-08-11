#!/usr/bin/env bash
#
# NAME
#	M202.GEN.BA.Deploy.sh - Deploy Estela Generic BA Server and components
#
# SYNOPSIS
#	M202.GEN.BA.Deploy.sh <m202.deploy.properties> 
#	M202.GEN.BA.Deploy.sh <m202.deploy.properties> FULL_DEPLOY <AUTOMATIC>
#		m202.deploy.properties = Deploy config file location and name
#		FULL_DEPLOY = Will execute PG*, BA* and PDI* secuentially
#		AUTOMATIC = Full automatic scripts deployment, (optional, default=N) (DANGER!!!)
#
# DESCRIPTION
# 	Bash script for Deploying the BAME Generic BA server

#set -e
#set -x

declare -A arr
declare -A hosts

AUTO=$3

MES=`date +%m`; export MES
DIA=`date +%d`; export DIA
ANO=`date +%Y`; export ANO
HOUR=`date +%H`; export HOUR
MINUTE=`date +%M`; export MINUTE
TIMESTAMP=$ANO$MES$DIA$HOUR$MINUTE

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

function config_pentahoBA(){
	echo "Configuring PentahoBA"
sed -i "s/^mondrian.rolap.aggregates.Use.*/mondrian.rolap.aggregates.Use=true/g" ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/pentaho-solutions/system/mondrian/mondrian.properties
sed -i "s/^mondrian.rolap.aggregates.Read.*/mondrian.rolap.aggregates.Read=true/g" ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/pentaho-solutions/system/mondrian/mondrian.properties
sed -i "s/^mondrian.result.limit.*/mondrian.result.limit=50000000/g" ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/pentaho-solutions/system/mondrian/mondrian.properties
sed -i "s/^mondrian.rolap.queryTimeout.*/mondrian.rolap.queryTimeout=600/g" ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/pentaho-solutions/system/mondrian/mondrian.properties
sed -i "s/^mondrian.rolap.maxConstraints.*/mondrian.rolap.maxConstraints=100000/g" ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/pentaho-solutions/system/mondrian/mondrian.properties
sed -i "s/-Xms2048m -Xmx6144m -XX:MaxPermSize=256m/-Xms${arr["ba.pentahoba.memorymin"]}m -Xmx${arr["ba.pentahoba.memory"]}m -XX:MaxPermSize=256m/g" ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/start-pentaho.sh


if [ ! -f ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/tomcat/lib/postgresql-42.2.5.jar ]; then
	echo "Installing postgresql jdbc 42.2.5 driver (to remove bug when creating multiple connections from java pentahoba)"
	wget -r -np -N https://jdbc.postgresql.org/download/postgresql-42.2.5.jar -q -O ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/tomcat/lib/postgresql-42.2.5.jar
	rm -rf ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/tomcat/lib/postgresql-9.3-1102-jdbc4.jar
fi


echo "Configuring Saiku and Waqr plugins"
cd ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/pentaho-solutions/system/
cp ${arr["ba.deploy.files"]}/saiku-plugin-p7.1-3.90.zip saiku-plugin-p7.1-3.90.zip
unzip -oq saiku-plugin-p7.1-3.90.zip
rm -rf saiku-plugin-p7.1-3.90.zip
# Waqr not in use
#unzip -oq ${arr["ba.deploy.files"]}/waqr-plugin-package-TRUNK-SNAPSHOT.zip -d ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/pentaho-solutions/system/
if [ ! -f saiku/license.lic ];then 
	cp -f ${arr["ba.deploy.files"]}/license_saiku.lic saiku/license.lic
fi;


cd saiku
mv lib/saiku-olap-util-3.90.jar ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/tomcat/webapps/pentaho/WEB-INF/lib/
mv lib/mondrian-3.11.0.0-353.jar lib/mondrian-3.11.0.0-353.jar.bak
sed -i "s/.*datasourceResolverClass.*PentahoDataSourceResolver.*//g" plugin.spring.xml

#DSP
cd ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/tomcat/webapps/pentaho/WEB-INF
cp -f ${arr["ba.deploy.files"]}/com.mysample.mondrian.dsp-1.0.0.jar lib/com.mysample.mondrian.dsp-1.0.0.jar

}

function publish_pentahoBA(){
	chmod +x ${arr["ba.deploy.files"]}/M202.GEN.BA.Publish.sh
	# Wait 100 seconds before Publishing reports/xmi/datasources to grant time to Pentaho to start
	nohup bash -c "sleep 100 && ${arr["ba.deploy.files"]}/M202.GEN.BA.Publish.sh ${arr["ba.deploy.files"]}/M202.GEN.BA.Deploy.properties Y" &
}

function deploy_metadataEtl(){
	echo "Deploying Metadata ETL into Pentaho BA infrastructure"
	rm -rf ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/tomcat/webapps/metadataEtl
	unzip -oq ${arr["ba.deploy.files"]}/metadataEtl.zip -d ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/tomcat/webapps/
	
	cd ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/tomcat/webapps/metadataEtl/WEB-INF/
	
	sed -i "s/HOSTNAME/${arr["postgre.prj.ip"]}/g" portofino-model.xml
	sed -i "s/PORT/${arr["postgre.prj.port"]}/g" portofino-model.xml
	sed -i "s/DATABASE/${arr["postgre.prj.database"]}/g" portofino-model.xml
	sed -i "s/USERNAME/${arr["postgre.prj.username"]}/g" portofino-model.xml
	sed -i "s/PASSWORD/${arr["postgre.prj.password"]}/g" portofino-model.xml
	
	# Recursivelly sed for DATABASE
	cd ..
	find WEB-INF/ -type f -exec sed -i "s/DATABASE/${arr["postgre.prj.database"]}/g" {} +
	mv WEB-INF/portofino-model/est_dwh WEB-INF/portofino-model/${arr["postgre.prj.database"]}
	
	cd ${arr["ba.pentahoba.deploy.dir"]}/pentaho-server/tomcat/webapps/metadataEtl/WEB-INF/groovy
	sed -i "s/ADMINPASSWORD/${arr["ba.pentahoba.password"]}/g" Security.groovy
}

function database_initiator(){
	echo "Database Inicialization"
	mkdir -p /tmp/${arr["ba.pentahoba.prj.description"]}.${TIMESTAMP}
	cp -r ${arr["ba.deploy.files"]}/82.BA_Modeling/* /tmp/${arr["ba.pentahoba.prj.description"]}.${TIMESTAMP}
	cd /tmp/${arr["ba.pentahoba.prj.description"]}.${TIMESTAMP}
	# Access to postgresql databases reconfiguration
	sed -i "s/^host_dwh=.*/host_dwh=${arr["postgre.prj.ip"]}/g" 55.DWH.initiator.sh
	sed -i "s/^port_dwh=.*/port_dwh=${arr["postgre.prj.port"]}/g" 55.DWH.initiator.sh
	sed -i "s/^db_dwh=.*/db_dwh=${arr["postgre.prj.database"]}/g" 55.DWH.initiator.sh
	sed -i "s/^user_dwh=.*/user_dwh=${arr["postgre.prj.username"]}/g" 55.DWH.initiator.sh
	sed -i "s/^pwd_dwh=.*/pwd_dwh=${arr["postgre.prj.password"]}/g" 55.DWH.initiator.sh
	chmod +x 55.DWH.initiator.sh
	echo "1"|./55.DWH.initiator.sh V1.0.0
	rm -rf /tmp/${arr["ba.pentahoba.prj.description"]}.${TIMESTAMP}
}

function database_updater(){
	echo "Database updater"
	mkdir -p /tmp/${arr["ba.pentahoba.prj.description"]}.${TIMESTAMP}
	cp -r ${arr["ba.deploy.files"]}/82.BA_Modeling/* /tmp/${arr["ba.pentahoba.prj.description"]}.${TIMESTAMP}
	if [ ! -f /tmp/${arr["ba.pentahoba.prj.description"]}.${TIMESTAMP}/updates/install_db_pg.sh ];
	then
	   echo "File install_db_pg.sh not found."
	else
		seguir=true;
		cd /tmp/${arr["ba.pentahoba.prj.description"]}.${TIMESTAMP}/updates/
		cp install_db_pg.sh install_db_pg.sh.${TIMESTAMP}
		chmod +x install_db_pg.sh.${TIMESTAMP}
		username=${arr["postgre.prj.username"]};
		password=${arr["postgre.prj.password"]};
		database=${arr["postgre.prj.database"]};
		serverip=${arr["postgre.prj.ip"]};
		serverport=${arr["postgre.prj.port"]};
		if [ seguir ];
		then
			sed -i "s#read DB;#DB=${database}#g" install_db_pg.sh.${TIMESTAMP}
			sed -i "s#read DB_USER;#DB_USER=${username}#g" install_db_pg.sh.${TIMESTAMP}
			sed -i "s#read -s DB_PASS#DB_PASS=${password}#g" install_db_pg.sh.${TIMESTAMP}
			sed -i "s#read SERVER#SERVER=${serverip}#g" install_db_pg.sh.${TIMESTAMP}
			sed -i "s#read PORT#PORT=${serverport}#g" install_db_pg.sh.${TIMESTAMP}
			sed -i "s#read NOTES#NOTES=\$USER@\$HOSTNAME.DB-Upgrade.AUTOMATIC#g" install_db_pg.sh.${TIMESTAMP}
			sed -i "s#read DIR_LOGS#DIR_LOGS=/var/log/BusinesAnalytics#g" install_db_pg.sh.${TIMESTAMP}
			sed -i "s#read DIR#DIR=${arr["ba.deploy.files"]}/82.BA_Modeling/updates/#g" install_db_pg.sh.${TIMESTAMP}
			sed -i "s#read ROLLBACK#ROLLBACK=N#g" install_db_pg.sh.${TIMESTAMP}
			if [ "$AUTO.a" = "Y.a" ];
			then
				sed -i "s#read action;#action=E#g" install_db_pg.sh.${TIMESTAMP}
				sed -i "s#read parar##g" install_db_pg.sh.${TIMESTAMP}
			fi
			./install_db_pg.sh.${TIMESTAMP} -i
		fi
	fi
	echo "Keeping deployment files: /tmp/${arr["ba.pentahoba.prj.description"]}.${TIMESTAMP} in case rollback is needed"
}


read_properties $1
case "$2" in 
	FULL_DEPLOY)
		echo ""
		echo ""
		echo "FULL DEPLOYMENT (single server) All data will be destroyed and all components reconfigured completly!!!, ENTER to continue, Ctrl+C to cancel"
		if [ "$AUTO.a" = "Y.a" ];
		then
			echo "Automatic deployment!!!"	
		else
			read sure
		fi
		config_pentahoBA
		publish_pentahoBA
		deploy_metadataEtl
		database_initiator
		database_updater
		;;
	*)
		echo ""
		echo ""
		echo ""
		echo "Usage: $0 <m202.deploy.properties> FULL_DEPLOY <AUTOMATIC>"
		echo ""
		exit 1
esac
echo "DONE"

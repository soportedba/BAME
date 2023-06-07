####################################################################################################################################
## AUTOMATIC EST_DWH DEPLOYMENT
####################################################################################################################################
##
## Required files
## 
## 
##
## usage: ./55.DWH.initiator.sh V1.0.0
##
## 			- Must exists subdirectory named: files.V1.0.0 to locate related files
####################################################################################################################################

# local database ip and port to deploy
host_dwh=x.x.x.x
port_dwh=5432
db_dwh=database
user_dwh=user
pwd_dwh=password

export PGPASSWORD=$pwd_dwh


echo "#################################################################################################################################################################"
echo "Deploy of metadataEtl, ENTER to continue, Ctrl+C to cancel"
echo "#################################################################################################################################################################"
read sure

echo "DIRECTORY EXISTENCE CHECK"
if [ ! -d "files.$1" ] ; then
echo "No files.$1 directory exists, error" 
exit 1
fi

pg_isready -p $port_dwh -h $host_dwh 
while [ $? -ne 0 ];
do
	sleep 5
	echo "TESTING DATABASE CONNECTIVITY"
	pg_isready -p $port_dwh -h $host_dwh 
done

if ! psql -qt -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh -c "SELECT to_regclass('public.mtdt_load_control');"|grep -w mtdt_load_control; then
	echo "TESTING EXISTENCE OF mtdt_load_control: NOT DETECTED, WILL CONTINUE WITH DATABASE INITIALITAION"
	#-- DATABASE PREPARATION, WE'LL REMOVE ALL EST_DWH
	echo "DATABASE PREPARATION, INCREMENTAL DEPLOYMENT, ERRORS COULD APPEAR BUT CAN BE OMITED IF OBJECTS ALREADY EXISTED" 
	echo "CREATE EXTENSION adminpack;"|/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh
	echo "CREATE EXTENSION tablefunc;"|/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh
	echo "CREATE EXTENSION dblink;"|/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh
	echo "GRANT EXECUTE ON FUNCTION dblink_connect_u(text) TO $user_dwh;"|/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh
	echo "GRANT EXECUTE ON FUNCTION dblink_connect_u(text, text) TO $user_dwh;"|/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh

	#-- METAMODEL LOAD (ddl, dml)
	echo "#################################################################################################################################################################"
	echo "METAMODEL DDL LOAD (TABLES)"
	echo "#################################################################################################################################################################"
	cat ./files.$1/50.Metadata_ETL.ddl.txt |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh
	echo "#################################################################################################################################################################"
	echo "METAMODEL DDL LOAD (FUNCTIONS/PROCEDURES)"
	echo "#################################################################################################################################################################"
	cat ./files.$1/SOURCE.pgsql/MTDT_LOAD_FULL.PROC |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_LOG_REGISTRATION.fnc |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_EXEC.fnc |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_LOAD_DDL.PROC |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_LOAD_INC.PROC |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_LOAD.PROC |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_LOAD_POST.fnc |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_LOAD_PRE_POST.PROC |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_GEN_SQL_CUBE.FNC |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_GEN_XML_CUBE.PROC |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_INDEXES.PROC |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	cat ./files.$1/SOURCE.pgsql/MTDT_DASHBOARD.PROC |/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh 
	echo "#################################################################################################################################################################"
	echo "DWH LOCAL CONTROL BASE TABLE GENERATION"
	echo "#################################################################################################################################################################"
	echo "insert into mtdt_load_control (fec_ini, fec_fin, completed,id_cube) values (now()-interval '100 year', now()-interval '100 year', 'N',10);"|/usr/bin/psql -p $port_dwh $db_dwh -h $host_dwh -U $user_dwh
	echo "FINISHED EXECUTION WITH FILES VERSION: files.$1"`date` 
else
	echo "TESTING EXISTENCE OF mtdt_load_control: DETECTED, NO DATABASE INITIALIZATION PERFORMED"
fi
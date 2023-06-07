#!/bin/bash
LY='\033[1;33m' # Light Yellow
LR='\033[1;31m' # Light Red
LG='\033[1;32m' # Light Green
NC='\033[0m' # No Color
FL="########################################################"
defaults=true;
for i in "$@"
do
case $i in
    -h|--help)
	echo -e "\n\nInteractive Deployment Proccess (HELP)"
	echo -e $FL$LG
	echo -e "\n\nUSAGE$NC"
	echo -e "\n./install_db.sh -h"
	echo -e "	This help"
	echo -e "\n./install_db.sh -i"
	echo -e "	Interactive deployment process, will ask for parameters: username, password, database name, host, port, db script location, log install location, notes, rollback"
	echo -e "\n./install_db.sh"
	echo -e "	Automatic deployment process, will ask for parameters: password, host, port and will execute all needed scripts without asking for confirmation."
	echo -e "	Defaults to some parameters: 
		USERNAME=postgres
		DATABASE NAME=postgres
		DB SCRIPT LOCATION=current dir
		LOG INSTALL LOCATION=/var/log/BusinesAnalytics
		NOTES=<user>@<hostname>.DB-Upgrade, ROLLBACK=N"
	echo -e "$LG\n\nASSUMPTIONS$NC"
	echo -e "\n\tinstall_db.sh script will register/update table \"versionHistory\" with field \"current\"=true for module (field \"module\") related in release.json, rows will also contain the field \"maxScriptId\" with the last executed id scripts into the database, an example of rows could be:
			\"release\" = \"EST_DWH 1.2.7.3616\",
			\"current\" = true,
			\"module\" = \"EST_DWH\",
			\"maxScriptId\" = 79
		";
	echo -e $NC
	exit 0
    ;;
    -i|--interactive)
	defaults=false;
    ;;
    *)
	#Nothing, will go ahead with interactive install
    ;;
esac
done

echo -e "\n\nInteractive Deployment Proccess"
echo -e $FL$LG
if $defaults ; then DB_USER="gamAdmin"; else 
	echo -e "Please insert USERNAME"
	read DB_USER; 
fi
echo "Please insert PASSWORD"
read -s DB_PASS
if $defaults ; 
then 
	DB="est_dwh"; 
else 
	echo "Please insert DATABASE NAME, EJ.- est_dwh"
	read DB; 
fi
echo "Please insert HOST of the Database, EJ.- 127.0.0.1 (Default: 127.0.0.1)"
read SERVER
echo "Please insert PORT of the Database, EJ.- 5432 (Default: 5432)"
read PORT
if $defaults ; 
then 
	DIR=`pwd`;
	DIR_LOGS="/var/log/BusinesAnalytics";
	NOTES=$USER"@"$HOSTNAME".DB-Upgrade";
	ROLLBACK="N";
else 
	echo "Please insert DB SCRIPT install_db.sh LOCATION , EJ.- /tmp (Default: current location)" 
	read DIR
	echo "Please insert LOG INSTALL LOCATION , EJ.- /var/log/BusinesAnalytics (Default: /var/log/BusinesAnalytics)" 
	read DIR_LOGS
	echo "Please insert NOTES of this deployment, EJ.- francisco.pardillo - upgrade (Default: <user>@<hostname>.DB-Upgrade)"
	read NOTES
	echo "Would you like to rollback some deployment? (Y/N) (Default=N)"
	read ROLLBACK
fi
echo -e $NC

exit_condition="N"
date_time=`date "+%Y%m%d%H%M%S"`
date_time_mongo=`date "+%Y-%m-%dT%H:%M:%SZ"`
current_dir=`pwd`

if [ "$SERVER""a" = "a" ]; then SERVER="127.0.0.1"; fi
if [ "$PORT""a" = "a" ]; then PORT="5432"; fi
if [ "$ROLLBACK""a" = "a" ]; then ROLLBACK="N"; fi
if [ "$DIR""a" = "a" ]; then DIR=`pwd`; fi
if [ "$DIR_LOGS""a" = "a" ]; then DIR_LOGS="/var/log/BusinesAnalytics"; fi
if [ "$NOTES""a" = "a" ]; then NOTES=$USER"@"$HOSTNAME".DB-Upgrade"; fi

log_file=$DIR_LOGS/install_db_$date_time.log

# DB connection
export PGPASSWORD=$DB_PASS
db_conn="psql -h $SERVER -p $PORT -U $DB_USER -w -d $DB -t";

CHK10="$LG""CHECK.010:Existence of release.json file$NC";
CHK11="$LG""CHECK.011:Readability of release.json file$NC";
CHK12="$LG""CHECK.012:Database connectivity$NC";
CHK17="$LG""CHECK.017:Existence of directory $DIR$NC";
CHK18="$LG""CHECK.018:Existence of directory $DIR_LOGS$NC";
CHK19="$LG""CHECK.019:Write permissions on log file $log_file$NC";
CHK20="$LG""CHECK.020:Rollback ID present$NC";
CHK21="$LG""CHECK.021:maxScriptId present in referenced release$NC";
CHK100="$LR""CHECK.100.Script execution error:$NC";

#CHANGE TO SCRIPT LOCATION
cd $DIR

if [ ! -d $DIR_LOGS ];then echo "Creating $DIR_LOGS directory"; mkdir -p $DIR_LOGS;fi
if [ ! -d $DIR_LOGS ];then exit_message=$exit_message"\nERROR:"$CHK18; exit_condition="Y";echo -e $CHK18"...Error";else echo -e $CHK18"...Ok";fi

touch $log_file
if [ $? -ne 0 ]; then exit_message=$exit_message"\nERROR:"$CHK19; exit_condition="Y";echo -e $CHK19"...Error";else echo -e $CHK19"...Ok";fi
if [ $exit_condition = "Y" ]; then echo -e "\n################################\nCanceling Deployment because of:\n"$exit_message; exit 0; fi

if [ ! -f release.json ]; then exit_message=$exit_message"\nERROR:"$CHK10; exit_condition="Y";echo -e $CHK10"...Error";else echo -e $CHK10"...Ok";fi
db_release_new=`cat release.json|grep release|cut -f 2 -d ":"|sed -e 's/\"//g' -e 's/ //g' -e 's/}//g'`
if [ $? -ne 0 ]; then exit_message=$exit_message"\nERROR:"$CHK11; exit_condition="Y";echo -e $CHK11"...Error";else echo -e $CHK11"...Ok";fi

if [ ! -f release.json ]; then exit_message=$exit_message"\nERROR:"$CHK10; exit_condition="Y";echo -e $CHK10"...Error";else echo -e $CHK10"...Ok";fi
db_module=`cat release.json |grep release|cut -f 2 -d ":"|cut -f 2 -d " "|cut -f 2 -d "\""`
if [ $? -ne 0 ]; then exit_message=$exit_message"\nERROR:"$CHK11; exit_condition="Y";echo -e $CHK11"...Error";else echo -e $CHK11"...Ok";fi

# Check existence of versionHistory and create it if no exists
db_exists_vh=`echo "select 1 from pg_tables where schemaname='public' and tablename='versionhistory'"|$db_conn --quiet`
if [ "$db_exists_vh""a" == "a" ]; then
				echo -e "DROP TYPE IF EXISTS scriptsitems;
CREATE TYPE scriptsitems AS (
    scriptName            varchar(100),
    scriptId     integer,
    execTime           timestamp(3)
);
CREATE TABLE IF NOT EXISTS versionHistory
(
   _ID BIGSERIAL primary key, 
   release varchar(100),
   current boolean,
   module varchar(100),
   datetime timestamp(3),
   notes varchar(1000),
   maxscriptid integer,
   scriptsarray scriptsitems[]
);" |$db_conn --quiet>> $log_file;
fi;

db_release_old=`echo "select release from versionhistory where module='$db_module' and current=true"|$db_conn --quiet`
if [ $? -ne 0 ]; then exit_message=$exit_message"\nERROR:"$CHK12; exit_condition="Y";db_error="Y";echo -e $CHK12"...Error";else echo -e $CHK12"...Ok";fi
if [ "$db_release_old""a" = "a" ]; then db_release_old="NOT FOUND";fi

# REGISTER CURRENT MODULE WITH OLD VERSIONING DATA AND REFACTOR OLD DATA STRUCTURE TO REMOVE CURRENT=TRUE
if [ "$db_release_old" = "NOT FOUND" ]; then
	for module in $db_module 
	do
		echo "update versionhistory set current=false where current=true"|$db_conn --quiet>> $log_file;
		# Set Database releases as old db_module releases
		echo "insert into versionHistory(release,current,module,datetime,notes,maxscriptid,scriptsarray) select release,true,'$db_module',datetime,notes,maxscriptid,scriptsarray from versionhistory where module='Database' and current=false"|$db_conn --quiet>> $log_file;
		db_release_old=`echo "select release from versionhistory where module='$db_module' and current=true"|$db_conn --quiet`
		# If no module has been registered, we will begin with new one
		if [ "$db_release_old""a" = "a" ]; then
				echo "insert into versionhistory(module,current) values ('$db_module',true)"|$db_conn --quiet>> $log_file;
				db_release_old=`echo "select release from versionhistory where module='$db_module' and current=true"|$db_conn --quiet`
		fi
	done
fi

db_maxScriptId=`echo "select maxscriptid from versionhistory where module='$db_module' and current=true"|$db_conn --quiet`
if [ $? -ne 0 ]; then db_maxScriptId="{\"maxScriptId\" : 0}";fi
if [ "$db_maxScriptId""a" = "a" ]; then db_maxScriptId="{\"maxScriptId\" : 0}";fi

if [ ! -d $DIR ];then exit_message=$exit_message"\nERROR:"$CHK17; exit_condition="Y";echo -e $CHK17"...Error";else echo -e $CHK17"...Ok";fi

#CHANGE TO js UPDATES DIRECTORY
cd $DIR/sql
echo $FL
echo -e "\n\nDeployment confirmation"
if [ $exit_condition = "Y" ]; then echo -e "\n################################\nCanceling Deployment because of:\n"$exit_message |tee -a $log_file; exit 0; fi
echo -e $FL$LG|tee -a $log_file
echo INSTALATION DIRECTORY:"      "$DIR|tee -a $log_file
echo DB_USER:"                    "$DB_USER|tee -a $log_file
echo DB:"                         "$DB|tee -a $log_file
echo SERVER:"                "$SERVER|tee -a $log_file
echo PORT:"                "$PORT|tee -a $log_file
echo ROLLBACK:"                   "$ROLLBACK|tee -a $log_file
echo NOTES:"                      "$NOTES|tee -a $log_file
echo |tee -a $log_file
echo MODULE:"         "$db_module|tee -a $log_file
echo CURRENT Release:"         "$db_release_old|tee -a $log_file
echo LAST script:"             "$db_maxScriptId|tee -a $log_file
echo|tee -a $log_file
if [ "$ROLLBACK" = "N" -o "$ROLLBACK" = "n" ]; then echo NEW Release:"                "$db_release_new|tee -a $log_file; fi
echo "ROLLBACK INSTALL?:          "$ROLLBACK|tee -a $log_file
echo|tee -a $log_file
echo INSTALL LOG FILE:"           "$log_file|tee -a $log_file
echo -e $NC$FL|tee -a $log_file
echo|tee -a $log_file
echo Ctrl+C to cancel or Intro to begin the install process.|tee -a $log_file
echo|tee -a $log_file
read parar

if [ $exit_condition = "Y" ]; then echo -e "\n################################\nCanceling Deployment because of:\n"$exit_message |tee -a $log_file; exit 0; fi

if [ $ROLLBACK = "N" ] || [ $ROLLBACK = "n" ]; then
	#GENERATE LIST OF UPDATE FILES
	maxScriptId_number=`echo "$db_maxScriptId"|sed -e "s/{//" -e "s/}//"|cut -f 2 -d ":"`
	if [ ! $maxScriptId_number ] || [ $maxScriptId_number"a" == "a" ]; then maxScriptId_number=0;fi
	echo "maxScriptId_number"$maxScriptId_number
	for j in `ls update*.sql|grep -v rollback|grep -v ROLLBACK`
	do
	update_number=`echo $j|cut -c 7-17`;
	diff=`expr $update_number - $maxScriptId_number`
	if [ $diff -gt 0 ]; then echo $j";"`expr $update_number + 0` >>files_$date_time.tmp; fi
	done
	
	#LOOP WHILE EXISTS UPDATE FILES
	if [ -f files_$date_time.tmp ]; then
	scriptsArray_new="array[";
		for j in `cat files_$date_time.tmp|sort -u`
		do
			file_update=`echo $j|cut -f 1 -d ";"`;
			file_message=`cat $file_update|grep "INSTALL ATTENTION"`;
			if $defaults ; 
			then 
				echo -e "\n\n$LG""You are about to execute $file_update\n$LY$file_message\n\n$NC"|tee -a $log_file
				action="E";
			else 
				echo -e "\n\n$LG""You are about to execute $file_update\n$LY$file_message\n\n$LG""Execute(E), Skip(S) or Cancel(C)$NC"|tee -a $log_file
				read action; 
			fi	
			echo -e "$LG""Selected action: "$action"\n$NC">>$log_file;
			if [ $action = "E" -o $action = "e" ]; then
				maxScriptId_new=`echo $j|cut -f 2 -d ";"`;
				if [ "$scriptsArray_new" = "array[" ]; then
					scriptsArray_new=$scriptsArray_new"ROW('$file_update', $maxScriptId_new,now())::scriptsitems";
				else
					scriptsArray_new=$scriptsArray_new",ROW('$file_update', $maxScriptId_new,now())::scriptsitems";
				fi
				$db_conn -f $file_update >> $log_file;
				if [ $? -ne 0 ]; 
				then 
					echo -e "\n$LR""ERROR:"$CHK100"$NC$file_update""\nPlease review log_file to check errors: $log_file"; 
					echo -e "\n$LR""Continue with deployment? Continue(Intro) or Cancel(C)$NC"|tee -a $log_file
					read action2; 
					if [ "$action2" = "C" -o "$action2" = "c" ]; then
					break;
					fi
				fi
			elif [ $action = "C" -o $action = "c" ]; then
				break;
			fi
		done
	scriptsArray_new=$scriptsArray_new"]";
	fi
	#LOOP FOR versionHistory
	#versionHistory register
	for module in $db_module 
	do
		#Will only register scriptsArray if there is someone to register, always will register the maxScriptId
		if [ ! "$scriptsArray_new" ] || [ ! "$maxScriptId_new" ]; then
			echo -e "$LG$module No need for version registering$NC"|tee -a $log_file;
		else
			#versionHistory.current will remain to true to only 1 doc (the last release)
			echo -e "$LG Version History Register:$NC"|tee -a $log_file;
			echo "insert into versionHistory(release,current,module,datetime,notes,maxscriptid,scriptsarray) select release,null,module,datetime,notes,maxscriptid,scriptsarray from versionhistory where module='$db_module' and current=true"|$db_conn --quiet>> $log_file;
			if [ $? -ne 0 ]; then echo -e "Error";else echo -e "Ok";  fi
			release="update versionhistory set release='$db_release_new',datetime=now(),notes='$NOTES',maxscriptid=$maxScriptId_new,scriptsarray=$scriptsArray_new where module='$module' and current=true"
			echo -e "$LG$module Version Register:$NC"|tee -a $log_file;
			echo $release|$db_conn --quiet>> $log_file;
			if [ $? -ne 0 ]; then echo -e "Error";else echo -e "Ok";  fi
		fi
	done
elif [ $ROLLBACK = "Y" ] || [ $ROLLBACK = "y" ]; then
	#ROLLBACK WILL BE PERFORMED FROM THE SELECTED RELEASE, (BASED IN THE ObjectId because of the duplicity posibility of release executed)
	#GENERATE LIST OF UPDATE FILES
	echo -e "\n\nList of last 20 release updates"
	echo -e $FL$LG|tee -a $log_file
	echo "select _id,module,release,notes from versionHistory where module='$db_module' and release not like '%rollback%' and current is not true order by _id limit 20"|$db_conn --quiet|tee -a $log_file;
	echo ""|tee -a $log_file
	echo -e $NC$FL|tee -a $log_file
	echo "Please select a release ID to ROLLBACK, EJ.- 15"|tee -a $log_file
	echo ""|tee -a $log_file
	echo ""|tee -a $log_file
	read RELEASE_ROLLBACK
	#Remove double quotes if present
	RELEASE_ROLLBACK=`echo $RELEASE_ROLLBACK|sed 's/\"//g'`
	echo ""|tee -a $log_file
	echo -e $LG"Selected release to ROLLBACK:"|tee -a $log_file
	echo ""|tee -a $log_file
	echo "select (t.sa).scriptname from (SELECT UNNEST(scriptsarray)::scriptsitems AS sa from versionhistory where _id=$RELEASE_ROLLBACK) as t"|$db_conn --quiet> files_$date_time.tmp.release;
	if [ ! -s files_$date_time.tmp.release ]; then exit_message=$exit_message"\nERROR:"$CHK20; exit_condition="Y";db_error="Y";echo -e $CHK20"...Error";else echo -e $CHK20"...Ok";fi
	if [ $exit_condition = "Y" ]; then echo -e "\n################################\nCanceling Deployment because of:\n"$exit_message |tee -a $log_file; exit 0; fi
	
	echo "\x on
		select * from versionhistory where _id=$RELEASE_ROLLBACK"|$db_conn --quiet|tee -a $log_file 
	echo ""|tee -a $log_file
	echo "Are you sure to rollback this release? (Y/N) (Default=N)"|tee -a $log_file
	echo ""|tee -a $log_file
	read RELEASE_ROLLBACK_Y
	
	if [ $RELEASE_ROLLBACK_Y = "Y" ] || [ $RELEASE_ROLLBACK_Y = "y" ]; then
		#GET MAXSCRIPTID
		db_maxScriptId=`echo "select maxscriptid from versionhistory where _id=$RELEASE_ROLLBACK"|$db_conn --quiet`		
		if [ $? -ne 0 ]; then exit_message=$exit_message"\nERROR:"$CHK12; exit_condition="Y";db_error="Y";echo -e $CHK12"...Error";else echo -e $CHK12"...Ok";fi
		if [ "$db_maxScriptId""a" = "{  }a" ]; then exit_message=$exit_message"\nERROR:"$CHK21; exit_condition="Y";db_error="Y";echo -e $CHK21"...Error";else echo -e $CHK21"...Ok";fi
		if [ $exit_condition = "Y" ]; then echo -e "\n################################\nCanceling Deployment because of:\n"$exit_message |tee -a $log_file; exit 0; fi
		
		maxScriptId_number=`echo "$db_maxScriptId"|sed -e "s/{//" -e "s/}//"|cut -f 2 -d ":"`
		
		for j in `cat files_$date_time.tmp.release |sed -e 's/\"//g' -e 's/ //g' -e 's/}//g' -e 's/.sql//'`
		do
			update_number=`echo $j|cut -c 7-17`;
			#SET update_number TO UPDATE_FILE -1 TO SET DB maxScriptId ACCORDLY
			if [ -f $j.rollback.sql ]; then echo $j.rollback.sql";"`expr $update_number - 1` >>files_$date_time.tmp; fi
		done
		if [ $? -ne 0 ]; then exit_message=$exit_message"\nERROR:090 could not get update number from rollback update files"; exit_condition="Y";  fi
		rm -rf files_$date_time.tmp.release;
		
		if [ $exit_condition = "Y" ]; then echo -e "\n################################\nCanceling Deployment because of:\n"$exit_message |tee -a $log_file; exit 0; fi
		
		#LOOP WHILE EXISTS ROLLBACK UPDATE FILES
		if [ -f files_$date_time.tmp ]; then
		scriptsArray_new="array[";
			for j in `cat files_$date_time.tmp|sort -ur`
			do
				file_update=`echo $j|cut -f 1 -d ";"`;
				file_message=`cat $file_update|grep "INSTALL ATTENTION"`;
				echo -e "\n\n$LG""You are about to execute rollback $file_update\n$LY$file_message\n\n$LG""Execute(E), Skip(S) or Cancel(C)$NC"|tee -a $log_file
				read action; 
				echo -e "$LG""Selected action: "$action"\n$NC">>$log_file;
				if [ $action = "E" -o $action = "e" ]; then
					maxScriptId_new=`echo $j|cut -f 2 -d ";"`;
					if [ "$scriptsArray_new" = "array[" ]; then
						scriptsArray_new=$scriptsArray_new"ROW('$file_update', $maxScriptId_new,now())::scriptsitems";
					else
						scriptsArray_new=$scriptsArray_new",ROW('$file_update', $maxScriptId_new,now())::scriptsitems";
					fi
					$db_conn -f $file_update >> $log_file;
					if [ $? -ne 0 ]; 
					then 
						echo -e "\n$LR""ERROR:"$CHK100"$NC$file_update""\nPlease review log_file to check errors: $log_file"; 
						echo -e "\n$LR""Continue with deployment? Continue(Intro) or Cancel(C)$NC"|tee -a $log_file
						read action2; 
						if [ "$action2" = "C" -o "$action2" = "c" ]; then
						break;
						fi
					fi
				elif [ $action = "C" -o $action = "c" ]; then
					break;
				fi
			done
		scriptsArray_new=$scriptsArray_new"]";
		fi
		#LOCATE RELEASE
		echo "select release from versionHistory where _id=$RELEASE_ROLLBACK and module='$db_module'"|$db_conn --quiet> files_$date_time.tmp.1.release;
		#GENERATE release.rollback
		release_number=`cat files_$date_time.tmp.1.release|sed -e 's/ //g'`.rollback
		echo ""|tee -a $log_file
		echo -e "$LG$db_module ROLLBACK Version to Register:$NC"|tee -a $log_file;
		echo $release_number
		rm -rf files_$date_time.tmp.1.release;	
		#LOOP FOR versionHistory
		#versionHistory register
		for module in $db_module
		do
			if [ ! "$scriptsArray_new" ] || [ ! "$maxScriptId_new" ]; then
				release="update versionhistory set release='$release_number',datetime=now(),notes='$NOTES',maxscriptid=$maxScriptId_number where module='$module' and current=true"
			else
				release="update versionhistory set release='$release_number',datetime=now(),notes='$NOTES',maxscriptid=$maxScriptId_new,scriptsarray=$scriptsArray_new where module='$module' and current=true"
			fi
			echo -e "$LG$module ROLLBACK Version Register:$NC"|tee -a $log_file;
			echo $release|$db_conn --quiet>> $log_file;
			if [ $? -ne 0 ]; then echo -e "Error";else echo -e "Ok";  fi
		done
		echo -e "$LG""Version History Register:$NC"|tee -a $log_file;
		echo "insert into versionHistory(release,current,module,datetime,notes,maxscriptid,scriptsarray) select release,null,module,datetime,notes,maxscriptid,scriptsarray from versionhistory where module='$db_module' and current=true"|$db_conn --quiet>> $log_file;
		if [ $? -ne 0 ]; then echo -e "Error";else echo -e "Ok";  fi
	fi
fi
rm -rf files_$date_time.tmp;

#!/bin/bash
set -e

DB_USER=${DB_USER:-postgres}
DB_PASS=${DB_PASS:-password}
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
INSTALL_PLUGINS=${INSTALL_PLUGINS:-false}

function persist_dirs() {
  echo "-----> persist dirs"

  if [ ! -d /pentaho-data/pentaho-solutions ]; then
	# If not existe data in persistent volume, then we create it
    mv $PENTAHO_HOME/pentaho-server/pentaho-solutions /pentaho-data/pentaho-solutions
  else
	# If already existe data in persistent volume, then we point to it
    mv $PENTAHO_HOME/pentaho-server/pentaho-solutions $PENTAHO_HOME/pentaho-server/pentaho-solutions.orig
  fi

  if [ ! -d /pentaho-data/tomcat ]; then
    mv $PENTAHO_HOME/pentaho-server/tomcat /pentaho-data/tomcat
  else
	mv $PENTAHO_HOME/pentaho-server/tomcat $PENTAHO_HOME/pentaho-server/tomcat.orig
  fi

  ln -s /pentaho-data/pentaho-solutions $PENTAHO_HOME/pentaho-server/pentaho-solutions
  ln -s /pentaho-data/tomcat $PENTAHO_HOME/pentaho-server/tomcat 
}

# TODO: Fix to work on Google Container Engine
function wait_database() {
  # TODO: Detect postgres port
  #port=$(env | grep DATABASE_PORT | grep TCP_PORT | cut -d = -f 2)
  port=5432

  echo -n "-----> waiting for database on $DB_HOST:$port ..."
  while ! nc -w 1 $DB_HOST $port 2>/dev/null
  do
    echo -n .
    sleep 1
  done

  echo '[OK]'
}

function setup_database() {
  echo "-----> setup database"
  echo "DB_USER: ${DB_USER}"
  echo "DB_PASS: ${DB_PASS}"
  echo "DB_HOST: ${DB_HOST}"
  echo "DB_PORT: ${DB_PORT}"

  wait_database

  sed -i "s/5432/${DB_PORT}/g" $PENTAHO_HOME/conf/repository.xml && \
  sed -i "s/\*\*host\*\*/${DB_HOST}/g" $PENTAHO_HOME/conf/repository.xml && \
  sed -i "s/\*\*password\*\*/${DB_PASS}/g" $PENTAHO_HOME/conf/repository.xml && \
  cp -fv $PENTAHO_HOME/conf/repository.xml \
    $PENTAHO_HOME/pentaho-server/pentaho-solutions/system/jackrabbit/repository.xml

  sed -i "s/5432/${DB_PORT}/g" $PENTAHO_HOME/conf/context.xml && \
  sed -i "s/\*\*host\*\*/${DB_HOST}/g" $PENTAHO_HOME/conf/context.xml && \
  sed -i "s/\*\*password\*\*/${DB_PASS}/g" $PENTAHO_HOME/conf/context.xml && \
  cp -fv $PENTAHO_HOME/conf/context.xml \
    $PENTAHO_HOME/pentaho-server/tomcat/webapps/pentaho/META-INF/context.xml

  sed -i "s/5432/${DB_PORT}/g" $PENTAHO_HOME/conf/applicationContext-spring-security-hibernate.properties && \
  sed -i "s/\*\*host\*\*/${DB_HOST}/g" $PENTAHO_HOME/conf/applicationContext-spring-security-hibernate.properties && \
  sed -i "s/\*\*password\*\*/${DB_PASS}/g" $PENTAHO_HOME/conf/applicationContext-spring-security-hibernate.properties && \
  cp -fv $PENTAHO_HOME/conf/applicationContext-spring-security-hibernate.properties \
    $PENTAHO_HOME/pentaho-server/pentaho-solutions/system/applicationContext-spring-security-hibernate.properties

  sed -i "s/5432/${DB_PORT}/g" $PENTAHO_HOME/conf/jdbc.properties && \
  sed -i "s/\*\*host\*\*/${DB_HOST}/g" $PENTAHO_HOME/conf/jdbc.properties && \
  sed -i "s/\*\*password\*\*/${DB_PASS}/g" $PENTAHO_HOME/conf/jdbc.properties && \
  cp -fv $PENTAHO_HOME/conf/jdbc.properties \
    $PENTAHO_HOME/pentaho-server/pentaho-solutions/system/simple-jndi/jdbc.properties

  sed -i 's/\\connect.*/\\connect quartz/g' \
    $PENTAHO_HOME/pentaho-server/data/postgresql/create_quartz_postgresql.sql

  sed -i 's/hsql/postgresql/g' \
    $PENTAHO_HOME/pentaho-server/pentaho-solutions/system/hibernate/hibernate-settings.xml

  sed -i "s/localhost/${DB_HOST}/g" \
    $PENTAHO_HOME/pentaho-server/pentaho-solutions/system/hibernate/postgresql.hibernate.cfg.xml

  sed -i 's/system\/hibernate\/hsql.hibernate.cfg.xml/system\/hibernate\/postgresql.hibernate.cfg.xml/g' \
    $PENTAHO_HOME/pentaho-server/pentaho-solutions/system/hibernate/hibernate-settings.xml

  export PGPASSWORD=$DB_PASS
  
  pg_isready -h $DB_HOST -p $DB_PORT
  while [ $? -ne 0 ];
  do
	sleep 5
	echo "-----> testing database connectivity"
	pg_isready -h $DB_HOST -p $DB_PORT
  done
  
  if ! psql -lqt -U $DB_USER -h $DB_HOST | grep -w hibernate; then
    echo "-----> importing sql files"

    psql -U $DB_USER -h $DB_HOST -p $DB_PORT -f $PENTAHO_HOME/pentaho-server/data/postgresql/create_jcr_postgresql.sql
    psql -U $DB_USER -h $DB_HOST -p $DB_PORT -f $PENTAHO_HOME/pentaho-server/data/postgresql/create_quartz_postgresql.sql
    psql -U $DB_USER -h $DB_HOST -p $DB_PORT -f $PENTAHO_HOME/pentaho-server/data/postgresql/create_repository_postgresql.sql
    
    psql -U $DB_USER -h $DB_HOST -p $DB_PORT -c "ALTER USER pentaho_user WITH PASSWORD '${DB_PASS}'"
    psql -U $DB_USER -h $DB_HOST -p $DB_PORT -c "ALTER USER jcr_user WITH PASSWORD '${DB_PASS}'"
    psql -U $DB_USER -h $DB_HOST -p $DB_PORT -c "ALTER USER hibuser WITH PASSWORD '${DB_PASS}'"

    # http://jira.pentaho.com/browse/BISERVER-10639
    # https://github.com/wmarinho/docker-pentaho/blob/5.3/config/postgresql/biserver-ce/data/postgresql/create_quartz_postgresql.sql#L37
    psql -U $DB_USER -h $DB_HOST -p $DB_PORT quartz -c 'CREATE TABLE "QRTZ" ( NAME VARCHAR(200) NOT NULL, PRIMARY KEY (NAME) );'
  fi
  unset PGPASSWORD

  touch /pentaho-data/.database.ok
}

function setup_tomcat() {
  echo "-----> setup webserver"

  rm -rf "$PENTAHO_HOME/pentaho-server/tomcat/conf/Catalina/*"
  rm -rf "$PENTAHO_HOME/pentaho-server/tomcat/temp/*"
  rm -rf "$PENTAHO_HOME/pentaho-server/tomcat/work/*"

  echo "org.pentaho.reporting.engine.classic.core.modules.output.pageable.pdf.Encoding=ISO-8859-1" >> \
    $PENTAHO_HOME/pentaho-server/tomcat/webapps/pentaho/WEB-INF/classes/classic-engine.properties

  touch /pentaho-data/.tomcat.ok
}

function setup_pentaho() {
  echo "-----> setup pentaho"

  # https://help.pentaho.com/Documentation/5.3/0P0/000/090
  sed -i "s/\(requestParameterAuthenticationEnabled\)\(.*\)/\1=true/g" \
    $PENTAHO_HOME/pentaho-server/pentaho-solutions/system/security.properties
}

function setup_plugins() {
  if [ "$INSTALL_PLUGINS" = true ] && [ ! -f /pentaho-data/.plugins.ok ]; then
    echo "-----> setup plugins"
    echo "-----> install ctools"

    wget --no-check-certificate 'https://raw.github.com/pmalves/ctools-installer/master/ctools-installer.sh' -P / -o /dev/null

    chmod +x /ctools-installer.sh

    /ctools-installer.sh \
      -s $PENTAHO_HOME/pentaho-server/pentaho-solutions \
      -w $PENTAHO_HOME/pentaho-server/tomcat/webapps/pentaho \
      -c cdf,cda,cde,cgg,cfr,cdc,cdv,saikuadhoc \
      --no-update \
      -y

    touch /pentaho-data/.plugins.ok
  fi
}

function setup_bameba(){
	chmod +x $PENTAHO_HOME/BAMEBA.docker/M202.GEN.BA.Deploy.sh
    $PENTAHO_HOME/BAMEBA.docker/M202.GEN.BA.Deploy.sh $PENTAHO_HOME/BAMEBA.docker/M202.GEN.BA.Deploy.properties FULL_DEPLOY Y
}

if [ "$1" = 'run' ]; then
  #persist_dirs
  setup_tomcat
  setup_pentaho
  setup_database
  setup_plugins
  setup_bameba

  echo "-----> starting hypersonic demo database"
  nohup bash -c "$PENTAHO_HOME/pentaho-server/data/start_hypersonic.sh" &
  echo "-----> starting pentaho"
  $PENTAHO_HOME/pentaho-server/start-pentaho.sh
else
  exec "$@"
fi
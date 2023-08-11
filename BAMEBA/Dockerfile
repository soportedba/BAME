FROM ubuntu:20.04

ENV BISERVER_VERSION 9.3
ENV BISERVER_TAG 9.3.0.0-428
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV PENTAHO_HOME /pentaho
ENV PENTAHO_JAVA_HOME $JAVA_HOME
ENV CATALINA_BASE $PENTAHO_HOME/pentaho-server/tomcat
ENV CATALINA_HOME $PENTAHO_HOME/pentaho-server/tomcat
ENV CATALINA_TMPDIR $PENTAHO_HOME/pentaho-server/tomcat/temp
ENV CLASSPATH $PENTAHO_HOME/pentaho-server/tomcat/bin/bootstrap.jar 
ENV CATALINA_OPTS=""
ENV PATH $PENTAHO_HOME/pentaho-server:$PATH
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y wget curl locales zip unzip netcat dnsutils postgresql-client-12 && \
	apt-get install -y ca-certificates && \
	update-ca-certificates -f -v && \
	apt-get install -y openjdk-8-jdk && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV TIMEZONE "Europe/Madrid"
ENV LOCALE "en_US.UTF-8 UTF-8"
ENV LANG "en_US.utf8"

RUN echo $TIMEZONE > /etc/timezone && \
    echo $LOCALE >> /etc/locale.gen && \
    locale-gen && \
    dpkg-reconfigure locales && \
    dpkg-reconfigure -f noninteractive tzdata

RUN /usr/bin/curl -kSL "https://privatefilesbucket-community-edition.s3.us-west-2.amazonaws.com/${BISERVER_TAG}/ce/server/pentaho-server-ce-${BISERVER_TAG}.zip" -o /tmp/pentaho-server-${BISERVER_TAG}.zip --retry 3 -C -

RUN /usr/bin/unzip -q /tmp/pentaho-server-${BISERVER_TAG}.zip -d $PENTAHO_HOME && \
    rm -f /tmp/pentaho-server-${BISERVER_TAG}.zip && \
    rm -f $PENTAHO_HOME/pentaho-server/promptuser.sh && \
    chmod +x $PENTAHO_HOME/pentaho-server/start-pentaho.sh && \
    sed -i -e 's/\(exec ".*"\) start/\1 run/' $PENTAHO_HOME/pentaho-server/tomcat/bin/startup.sh

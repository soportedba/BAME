FROM ubuntu:20.04

ENV PDI_VERSION 9.3
ENV PDI_TAG 9.3.0.0-428
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV PENTAHO_HOME /pentahoetl
ENV PENTAHO_JAVA_HOME $JAVA_HOME
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

RUN /usr/bin/curl -kSL "https://privatefilesbucket-community-edition.s3.us-west-2.amazonaws.com/${PDI_TAG}/ce/client-tools/pdi-ce-${PDI_TAG}.zip" -o /tmp/pdi-ce-${PDI_TAG}.zip --retry 3 -C -

RUN /usr/bin/unzip -q /tmp/pdi-ce-${PDI_TAG}.zip -d $PENTAHO_HOME && \
    rm -f /tmp/pdi-ce-${PDI_TAG}.zip


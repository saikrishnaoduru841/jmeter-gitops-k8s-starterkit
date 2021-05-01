ARG JMETER_VERSION
FROM rbillon59/jmeter-k8s-base:${JMETER_VERSION}


ARG PROJECT
ENV ENV_PROJECT=${PROJECT}


COPY scenario /tmp/scenario
COPY entrypoint.sh /tmp/entrypoint.sh

# Add modules and JMX to jmeter bin / add csv dataset files
RUN find /tmp/scenario -name '*.jmx' -exec cp --target-directory /opt/jmeter/apache-jmeter/bin {} +

USER jmeter
WORKDIR /opt/jmeter/apache-jmeter/bin

# Installing needed plugins for the test
RUN bash PluginsManagerCMD.sh install-for-jmx "/opt/jmeter/apache-jmeter/bin/${PROJECT}.jmx"

ENTRYPOINT "/tmp/entrypoint.sh" ${ENV_PROJECT}


#!/bin/bash

# Get project from Dockerfile
project="${1}"
jmeter_path="/opt/jmeter/apache-jmeter/bin"


source "/tmp/scenario/${project}/.env"


if [ "${MODE}" == "SLAVE" ]; then

    echo "Launching slave pod"

    ## Splitting CSV into equal pieces for all injectors

    nb_digit="${#nb_injectors}"
    mkdir "/tmp/split"

    for csvFileFull in $(find /tmp/scenario/ -name *.csv)
        do
            echo "Processing ${csvFileFull}"
            csvfile="${csvFileFull##*/}"
            lines_total=$(cat "${csvFileFull}" | wc -l)
            split --suffix-length="${nb_digit}" -d -l $((lines_total/nb_injectors)) "${csvFileFull}" "/tmp/split/"

            # Getting the right file 
            jvm_id=$(echo "$(hostname)" | awk -F "-" '{print $3}')
            cp "/tmp/split/${jvm_id}" "${jmeter_path}/${csvfile}"
    done

    echo "Starting $(hostname)"
    jmeter-server -n -Dserver.rmi.localport=50000 -Dserver_port=1099 -Jserver.rmi.ssl.disable=true
fi

if [ "${MODE}" == "MASTER" ]; then
    echo "Launching JMeter master $(hostname)"
    param_host="-Ghost=${host} -Gport=${port} -Gprotocol=${protocol}"
    param_user="-Gthreads=${threads} -Gduration=${duration} -Grampup=${rampup}"

    set -x
    jmeter ${param_host} ${param_user} --logfile ${project}_$(date +"%F_%H%M%S").jtl --nongui --testfile ${project}.jmx -Dserver.rmi.ssl.disable=true --remotestart $(getent ahostsv4 jmeter-slaves-svc | cut -d" " -f1 | sort -u | awk -v ORS=, '{print $1}' | sed 's/,$//')


fi
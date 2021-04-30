#!/usr/bin/env bash

set -e

#=== FUNCTION ================================================================
#        NAME: logit
# DESCRIPTION: Log into file and screen.
# PARAMETER - 1 : Level (ERROR, INFO)
#           - 2 : Message
#
#===============================================================================
logit()
{
    case "$1" in
        "INFO")
            echo -e " [\e[94m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ] $2 \e[0m" ;;
        "WARN")
            echo -e " [\e[93m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ]  \e[93m $2 \e[0m " && sleep 2 ;;
        "ERROR")
            echo -e " [\e[91m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ]  $2 \e[0m " ;;
    esac
   
}

#=== FUNCTION ================================================================
#        NAME: usage
# DESCRIPTION: Helper of the function
# PARAMETER - None
#
#===============================================================================

usage()
{
  logit "INFO" "-n <namespace>"
  logit "INFO" "-p <project>"
  logit "INFO" "example : ./deploy_jmeter.sh -n jmeter -p my-scenario"
  exit 1
}

# Checking if there is at least one param passed to the script

if [ "$#" -eq 0 ]
  then
    usage
fi

# Parsing the arguments

while getopts 'hn:p:' option;
    do
      case $option in
        n	  )	export namespace=${OPTARG}   ;;
        p   ) export project=${OPTARG}     ;;
        h   )   usage ;;
        ?   )   usage ;;
    	esac
done

if [ -z "${project}" ]; then
  logit "ERROR" "You need to provide the -p flag with the project to run. Usually the project is the folder name in scenario/"
  usage
fi

###################################
#                                 #
#  Creating the JMeter namespace  #
#                                 #
###################################


logit "INFO" "checking if kubectl is present"

if ! hash kubectl 2>/dev/null
then
    logit "INFO" "kubectl was not found in PATH"
    exit 1
fi

logit "INFO" "$(kubectl version --short)"
logit "INFO" "Current list of namespaces on the kubernetes cluster:"
logit "INFO" "$(kubectl get namespaces | grep -v NAME | awk '{print $1}')"
logit "INFO" "Checking If ${namespace} namespace exists"



if kubectl get namespace "${namespace}" > /dev/null 2>&1
then
  logit "ERROR" "Namespace ${namespace} already exists, please select a unique name"
  exit 1
fi

logit "INFO" "Creating Namespace: ${namespace}"
kubectl create namespace "${namespace}"

logit "INFO" "Namespace ${namespace} has been created"
logit "INFO" "Creating Jmeter slave nodes"

nodes=$(kubectl get nodes | grep -c -v "NAME")

logit "INFO" "Number of worker nodes on this cluster is ${nodes}"

#######################
#                     #
#  Deploying JMeter   #
#                     #
#######################

source "scenario/${project}/.env"

logit "INFO" "Creating jmeter deployments"
kubectl create -n "${namespace}" -f "deploy_slaves.yaml"
kubectl -n "${namespace}" scale statefulsets jmeter-slaves --replicas=${nb_injectors}

logit "INFO" "Waiting for slaves to be up and ready"
logit "INFO" "$(kubectl get -n ${namespace} all)"

kubectl -n "${namespace}" rollout status StatefulSet/jmeter-slaves

logit "INFO" "All slaves are ready, starting the JMeter controller"

kubectl create -n "${namespace}" -f "deploy_master.yaml"

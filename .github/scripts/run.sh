#!/bin/bash

# Colors for printf. Hell yeah!...
RED='\033[0;31m'
BRED='\033[1;31m'
GREEN='\033[0;32m'
BGREEN='\033[1;32m'
CYAN='\033[0;36m'
BCYAN='\033[1;36m'
NC='\033[0m' # No Color

if [[ ! $(command -v az &> /dev/null) -eq 0 && ! $(command -v kubectl &> /dev/null) -eq 0 ]]
then
    printf "${BRED}This script requires a logged in Azure-CLI and authenticated Kubectl!${NC}\n\n"
    exit 1
fi

if [[ $(uname -s) == "Darwin" ]]
then
    SED_ARG="-i \'\'"
else
    SED_ARG="-i"
fi

## -Set some variables
printf "Insert the namespace where the deployment will reside:\n"
read K8S_NAMESPACE

CURRENT_DIR=$(pwd)
GITHUB_REPO_NAME=$(basename -s .git `git config --get remote.origin.url`)
REGISTRY_SUB="Drift"
REGISTRY_NAME="plattform";
SP_ROLE="acrpush"
SP_NAME="sp-${GITHUB_REPO_NAME}-githubactions";
K8S_SA_NAME="${GITHUB_REPO_NAME}-githubactions"
K8S_HOST=$(kubectl -n ingress-nginx get certificate ingress-wildcard -o "jsonpath={.spec.dnsNames[0]}")

printf "\n${BGREEN}----------------------------------------${NC}\n"
printf "${RED}Make sure you are connected to the VPN in order to reach the cluster API${NC}\n"
printf "${RED}Make sure you have kubectl set to correct context (Cluster and namespace) and that the namespace ${BRED}exist${RED} before continuing!${NC}\n"
printf "${GREEN}If you need to create the namespace first, do this via the mknamespace url for your corresponding cluster: ${CYAN}https://confluence.nrk.no/display/PLAT/Liste+over+kubernetes+clustre+og+config${NC}\n\n"
printf "\nThe deployment will get the name: ${BCYAN}${GITHUB_REPO_NAME}${NC}"
printf "\nThe service will get the name: ${BCYAN}${GITHUB_REPO_NAME}${NC}"
printf "\nThe ingress will get the name: ${BCYAN}${GITHUB_REPO_NAME}${NC}"
printf "\nIt will be deployed in the namespace: ${BCYAN}${K8S_NAMESPACE}${NC}"
printf "\nKubernetes Service account will be named: ${BCYAN}${K8S_SA_NAME}${NC}"
printf "\nThe hostname of the ingress will be: ${BCYAN}${GITHUB_REPO_NAME}.${K8S_HOST:2}${NC}"
printf "\nThe Azure Service Principal will be named: ${BCYAN}${SP_NAME}${NC}"
printf "\n${BGREEN}----------------------------------------${NC}\n\n"

read -p $'\e[1;32mPress [Enter] key to create...\e[0m' key


## Create Serviceprincipal in Azure with access to push to the registry "Plattform"
SP_ACR_ID=$(az acr show --subscription ${REGISTRY_SUB} --name $REGISTRY_NAME --query id --output tsv);
ACR_LOGIN_SERVER=$(az acr show --subscription ${REGISTRY_SUB} --name $REGISTRY_NAME --query loginServer --output tsv);
SP_PASS=$(az ad sp create-for-rbac --years 99 --name ${SP_NAME} --scopes ${SP_ACR_ID} --role ${SP_ROLE} --query password --output tsv);
SP_ID=$(az ad sp show --id http://${SP_NAME} --query appId --output tsv);
K8S_ROLE_RESOURCES="configmaps,cronjobs,daemonsets,deployments,apps/deployments,endpoints,events,horizontalpodautoscalers,ingresses,jobs,persistentvolumeclaims,pods,replicasets,replicationcontrollers,secrets,services,statefulsets"


## Search and replace in role yaml
sed ${SED_ARG} 's/{{NAMESPACE}}/'${K8S_NAMESPACE}'/g' ${CURRENT_DIR}/.github/scripts/roles/*.yml

## Create serviceaccount,role and rolebinding in the namespace
# kubectl create sa --namespace ${K8S_NAMESPACE} ${K8S_SA_NAME}
# kubectl create role --namespace ${K8S_NAMESPACE} github-action --verb=get,list,watch,create,update,patch --resource=${K8S_ROLE_RESOURCES}
# kubectl create rolebinding --namespace ${K8S_NAMESPACE} github-action --role=github-action --serviceaccount=${K8S_NAMESPACE}:${K8S_SA_NAME}
kubectl apply -f .github/scripts/roles/sa.yml
kubectl apply -f .github/scripts/roles/role.yml
kubectl apply -f .github/scripts/roles/rolebinding.yml

K8S_SA_SECRET=$(kubectl get secret --namespace ${K8S_NAMESPACE} $(kubectl get serviceaccounts --namespace ${K8S_NAMESPACE} ${K8S_SA_NAME} -o 'jsonpath={.secrets[*].name}') -o yaml)

## Get the API endpoint of the cluster
K8S_API=$(kubectl config view --minify -o 'jsonpath={.clusters[0].cluster.server}')

## Search and replace application-name in deployments, service and ingress.
sed ${SED_ARG} 's/{{APP_NAME}}/'${GITHUB_REPO_NAME}'/g' ${CURRENT_DIR}/manifests/*/*.yml
sed ${SED_ARG} 's/{{IMAGE_NAME}}/'${REGISTRY_NAME}'.azurecr.io\/'${GITHUB_REPO_NAME}'\/master:latest/g' ${CURRENT_DIR}/manifests/master/*.yml
sed ${SED_ARG} 's/{{IMAGE_NAME}}/'${REGISTRY_NAME}'.azurecr.io\/'${GITHUB_REPO_NAME}'\/test:latest/g' ${CURRENT_DIR}/manifests/test/*.yml
sed ${SED_ARG} 's/{{CLUSTER_HOST}}/'${K8S_HOST:2}'/g' ${CURRENT_DIR}/manifests/*/*.yml

## Search and replace in workflow files
sed ${SED_ARG} 's/{{BRANCH}}/'${BRANCH}'/g' ${CURRENT_DIR}/.github/workflows/*.yaml
sed ${SED_ARG} 's/{{APP_NAME}}/'${GITHUB_REPO_NAME}'/g' ${CURRENT_DIR}/.github/workflows/*.yaml
sed ${SED_ARG} 's/{{K8S_API}}/'${K8S_API/\/\//\\/\\/}'/g' ${CURRENT_DIR}/.github/workflows/*.yaml
sed ${SED_ARG} 's/{{NAMESPACE}}/'${K8S_NAMESPACE}'/g' ${CURRENT_DIR}/.github/workflows/*.yaml
sed ${SED_ARG} 's/{{CONTAINER_REGISTRY}}/'${REGISTRY_NAME}'.azurecr.io/g' ${CURRENT_DIR}/.github/workflows/*.yaml

# README badge for status
cp ${CURRENT_DIR}/.github/scripts/README.md /tmp/README.md
sed ${SED_ARG} 's/{REPO_NAME}/'${GITHUB_REPO_NAME}'/g' /tmp/README.md
cat /tmp/README.md > README.md

## Print final info and instructions
printf "\n\n"
printf "You need to create secrets that the output needs to be put into on the repo ( ${CYAN}https://github.com/nrkno/${GITHUB_REPO_NAME}/settings/secrets${NC} ):\n"
printf "secret name:           secret value:\n"
printf "K8S_SA_SECRET: \n ${BCYAN}${K8S_SA_SECRET}${NC} \n"
printf "REGISTRY_USERNAME: ${BCYAN}${SP_ID}${NC}\n"
printf "REGISTRY_PASSWORD: ${BCYAN}${SP_PASS}${NC}\n"
printf "\n"
printf '(You may call it something else, but remember to also change the workflow yml file)\n\n'
printf "${GREEN}Manifest files have now been edited by this script. Please review to ensure they are correct and/or correct them as needed.${NC}\n"
printf "${GREEN}Feel free to change the manifests files to your liking.${NC}\n"
printf "${GREEN}The names generated from this script is not the required names but instead is meant as a simple start to get you going.${NC}\n"

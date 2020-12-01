#!/bin/bash
CYAN='\033[0;36m'
NC='\033[0m' # No Color
CURRENT_DIR=$(pwd)
GITHUB_REPO_NAME=$(basename -s .git `git config --get remote.origin.url`)
REGISTRY_SUB="Drift"
REGISTRY_NAME="plattform";
SP_ROLE="acrpush"
SP_NAME="sp-${GITHUB_REPO_NAME}-githubactions";
AZ_COMMAND=$(which az)

## Check for az command
which az > /dev/null
if [ $? -ne "0" ]; then
  echo "az command not present. Bailing out."
  exit 1
fi

## Create Serviceprincipal in Azure with access to push to the registry "Plattform"
SP_ACR_ID=$($AZ_COMMAND acr show --subscription ${REGISTRY_SUB} --name $REGISTRY_NAME --query id --output tsv);
ACR_LOGIN_SERVER=$($AZ_COMMAND acr show --subscription ${REGISTRY_SUB} --name $REGISTRY_NAME --query loginServer --output tsv);
SP_PASS=$($AZ_COMMAND ad sp create-for-rbac --years 99 --name ${SP_NAME} --scopes ${SP_ACR_ID} --role ${SP_ROLE} --query password --output tsv);
SP_ID=$($AZ_COMMAND ad sp show --id http://${SP_NAME} --query appId --output tsv);

# Output the password
printf "\n\n"
printf "REGISTRY_USERNAME: \n ${BCYAN}${SP_ID}${NC}\n"
printf "REGISTRY_PASSWORD: \n ${BCYAN}${SP_PASS}${NC}\n"

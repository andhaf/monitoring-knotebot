#!/usr/bin/env python3

import os
import subprocess
import fileinput
import re
import shutil

#populate the variables
remote_repo = subprocess.run(['git', 'config', '--get', 'remote.origin.url'], check=True, stdout=subprocess.PIPE, universal_newlines=True)
github_repo_name = subprocess.run(['basename', '-s', '.git', '%s' % remote_repo.stdout.strip() ], check=True, stdout=subprocess.PIPE, universal_newlines=True)
k8s_api = subprocess.run(['bash', 'fetch_api.sh'], cwd=".github/scripts", check=True, stdout=subprocess.PIPE, universal_newlines=True)
cur_context = subprocess.run(['kubectl', 'config', 'current-context'], check=True, stdout=subprocess.PIPE, universal_newlines=True)
cur_namespace = subprocess.run(['kubectl', 'config', 'view', '-o', 'jsonpath={.contexts[?(@.name == "%s")].context.namespace}' % cur_context.stdout.strip() ], check=True, stdout=subprocess.PIPE, universal_newlines=True)
cur_k8s_host = subprocess.run(['kubectl', '-n', 'ingress-nginx', 'get', 'certificate', 'ingress-wildcard', '-o', 'jsonpath={.spec.dnsNames[0]}'], check=True, stdout=subprocess.PIPE, universal_newlines=True)
image_name_master = "plattform.azurecr.io" + "/" + github_repo_name.stdout.strip() + "/" + "master" + ":" + "latest"
image_name_test = "plattform.azurecr.io" + "/" + github_repo_name.stdout.strip() + "/" + "test" + ":" + "latest"

# print out the variables for debugging
print (f'Printing out the variables')
print (f'Github repository name: {github_repo_name.stdout.strip()}')
print (f'Image url: {image_name}')
print (f'\n')
print (f'k8s api url we will use: {k8s_api.stdout.strip()}')
print (f'Current context (cluster): {cur_context.stdout.strip()}')
print (f'Current namespace: {cur_namespace.stdout.strip()}')
print (f'\n')
print (f'Current k8s ingress-wildcard certificate: {cur_k8s_host.stdout.strip()}')
print (f'\n')
print (f'Proceeding..'}
print (f'\n')

def search_and_sub(file, find, replace):
    print (f'Populating file: {file} with: {replace}')
    for line in fileinput.input(file, inplace=1):
        line = re.sub(find, replace, line.rstrip())
        print(line)

# substitution into the README...
search_and_sub(".github/scripts/README.md", "{REPO_NAME}", github_repo_name.stdout.strip())
# ...put the modified README at the right place
shutil.copyfile(".github/scripts/README.md", "./README.md")

# substitutions into the master workflow
search_and_sub(".github/workflows/docker-build-push-master.yaml", "{{CONTAINER_REGISTRY}}", "plattform.azurecr.io")
search_and_sub(".github/workflows/docker-build-push-master.yaml", "{{APP_NAME}}", github_repo_name.stdout.strip())
search_and_sub(".github/workflows/docker-build-push-master.yaml", "{{K8S_API}}", k8s_api.stdout)
search_and_sub(".github/workflows/docker-build-push-master.yaml", "{{NAMESPACE}}", cur_namespace.stdout)

# substitutions into master manifests
search_and_sub("manifests/master/deployment.yml", "{{APP_NAME}}", github_repo_name.stdout.strip())
search_and_sub("manifests/master/service.yml", "{{APP_NAME}}", github_repo_name.stdout.strip())
search_and_sub("manifests/master/ingress.yml", "{{CLUSTER_HOST}}", cur_k8s_host.stdout.split(".",1)[1])
search_and_sub("manifests/master/ingress.yml", "{{APP_NAME}}", github_repo_name.stdout.strip())
search_and_sub("manifests/master/deployment.yml", "{{IMAGE_NAME}}", image_name_master)

# substitutions into the test workflow
search_and_sub(".github/workflows/docker-build-push-test.yaml", "{{CONTAINER_REGISTRY}}", "plattform.azurecr.io")
search_and_sub(".github/workflows/docker-build-push-test.yaml", "{{APP_NAME}}", github_repo_name.stdout.strip())
search_and_sub(".github/workflows/docker-build-push-test.yaml", "{{K8S_API}}", k8s_api.stdout)
search_and_sub(".github/workflows/docker-build-push-test.yaml", "{{NAMESPACE}}", cur_namespace.stdout)

# substitutions into test manifests
search_and_sub("manifests/test/deployment.yml", "{{APP_NAME}}", github_repo_name.stdout.strip())
search_and_sub("manifests/test/service.yml", "{{APP_NAME}}", github_repo_name.stdout.strip())
search_and_sub("manifests/test/ingress.yml", "{{CLUSTER_HOST}}", cur_k8s_host.stdout.split(".",1)[1])
search_and_sub("manifests/test/ingress.yml", "{{APP_NAME}}", github_repo_name.stdout.strip())
search_and_sub("manifests/test/deployment.yml", "{{IMAGE_NAME}}", image_name_test)

# substitution in the roles
search_and_sub(".github/scripts/roles/role.yml", "{{NAMESPACE}}", cur_namespace.stdout)
search_and_sub(".github/scripts/roles/rolebinding.yml", "{{NAMESPACE}}", cur_namespace.stdout)
search_and_sub(".github/scripts/roles/sa.yml", "{{NAMESPACE}}", cur_namespace.stdout)

# print message when this is done
print (f'Done populating all files, now we need to fix the secrets.')

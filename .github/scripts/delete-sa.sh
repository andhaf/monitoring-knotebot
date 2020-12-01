#!/bin/bash
SA_NAME=$(basename -s .git `git config --get remote.origin.url`)-githubactions

kubectl delete role github-action
kubectl delete rolebinding github-action
kubectl delete sa $SA_NAME

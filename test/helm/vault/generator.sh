#!/usr/bin/env bash

set -eu

# $PROJECT    = The GCP project of the GKE cluster (defaults to k8s-staging)
# $WORKSPACE  = The Terraform workspace (defaults to devops)

project=${PROJECT:-k8s-staging}
workspace=${WORKSPACE:-uat}
size=${1}

if [[ ${size} == "large" ]]; then
  replicas=3
else
  replicas=1
fi

PROJECT=${project} REGION="global" WORKSPACE=${workspace} gomplate -f config.tpl.hcl -o config.hcl
PROJECT=${project} REGION="global" REPLICAS=${replicas} gomplate -f values.tpl.yaml -o values.yaml
yq write -i values.yaml server.ha.config "$(cat config.hcl)"

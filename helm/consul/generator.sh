#!/usr/bin/env bash

set -eu

# $WORKSPACE = The Terraform Workspace

workspace=${WORKSPACE:-dev}
size=${1}

if [[ ${size} == "large" ]]; then
  replicas=3
else
  replicas=1
fi

WORKSPACE=${workspace} REPLICAS=${replicas} gomplate -f values.tpl.yaml -o values.yaml

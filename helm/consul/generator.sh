#!/usr/bin/env bash

set -eu

# $WORKSPACE = The Terraform Workspace

workspace=${WORKSPACE:-devops}

WORKSPACE=${workspace} gomplate -f values.tpl.yaml -o values.yaml

#!/usr/bin/env bash

set -eu

export vault_token=${VAULT_TOKEN}
export VAULT_ADDR=http://localhost:8200
vault login -no-print -method=token token="${VAULT_TOKEN}"
# if using gke..  echo $(vault kv get -field=credentials-json secret/kubernetes/auth | base64 --decode >deployment-manager.json)
# if using gke.. gcloud auth activate-service-account --key-file deployment-manager.json
cd ./src/replicator
# if using gke..  ./gke-login.sh devops europe-west4 beamery-staging
export target_token=$(vault kv get -field=root_token secret/vault/${1})
sed -i -- 's/<target_environment>/'"${1}"'/g' ./config.yaml
sed -i -- 's/<target_kubecontext>/'"${1}"'/g' ./config.yaml
go run main.go
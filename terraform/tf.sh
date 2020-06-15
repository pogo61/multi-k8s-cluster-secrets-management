#!/usr/bin/env bash

set -eu

workspace=${1}
size=${2}
shift 2

if [[ -f "${workspace}.tfvars" ]]; then
	size="${workspace}"
fi

VAULT_ADDR=https://vault.global.DNS
export MASTER_VAULT_ADDR
unset MASTER_VAULT_TOKEN
vault token lookup &>/dev/null || vault login -no-print -method=github token="${GITHUB_API_TOKEN}"

if [[ ! -s "terraform.json" ]]; then
	vault kv get -field=terraform secret/iam | base64 --decode >terraform.json
fi

GOOGLE_CREDENTIALS=$(realpath terraform.json)
export GOOGLE_CREDENTIALS

echo "workspace: ${workspace}, size: ${size}"

if [[ ${1} != "init" ]]; then
	terraform workspace select "${workspace}"
fi

if [[ ${1} == "import" ]]; then
	shift 1
	terraform import -var-file="${size}.tfvars" "$@"
else
	terraform "$@" -var-file="${size}.tfvars"
fi

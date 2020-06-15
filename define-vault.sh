#!/usr/bin/env bash

# $WORKSPACE = The Terraform Workspace
# $SIZE      = The TFVars file
# $CLUSTER   = The name of the GKE cluster (falls back to $WORKSPACE if empty)
# $REGION    = The GCP region of the GKE cluster (defaults to us-west1)
# $PROJECT   = The GCP project of th GKE cluster (defaults to staging)

set -eu
GREEN=$'\e[1;32m'
RESET=$'\e[0m'

workspace=${1:-${WORKSPACE}}
size=${2:-${SIZE}}
image_file=${VERSIONS_FILE:-${PWD}/image.yaml}

function deploy_helm() {
	local app_name="${1}"
	local path="helm/${1}"
	local namespace="${2}"
	local size="${3}"
	chart=$(yq read "${versions_file}" "${app_name}")

  printf "\n${GREEN}====== %s %s ======${RESET}\n" "installing" "${app_name}"

	(
		cd "${path}"
		./generator.sh "${size}"
		helm upgrade --install "${app_name}" "${chart}" -f values.yaml --namespace "${namespace}" --cleanup-on-fail --wait
	)
}

function configure_vault() {
	local script_path="${1}"
	pwd=$(pwd)
	cd "${script_path}"
	# shellcheck disable=SC2012
	ls | sort -V

  printf "\n${GREEN}====== %s %s ======${RESET}\n" "configuring" "vault"

	for f in *; do
		chmod +x "${f}"
		eval "./${f} ${2}" || true
	done

	cd "${pwd}"
}

gcloud beta container clusters get-credentials "${CLUSTER:-${workspace}}" --region "${REGION:-us-west1}" --project "${PROJECT:-staging}"

deploy_helm "consul" "vault" "${size}"
deploy_helm "vault" "vault" "${size}"

sleep 10
vault_init_result=$(kubectl -n vault exec -it vault-0 -- vault operator init -n 1 -t 1 -format=json || true)
case ${vault_init_result} in
*"recovery_keys_hex"*)
	echo "${vault_init_result}" >vault.json
	vault kv put "secret/vault/${workspace}" @vault.json
	rm vault.json
	;;
*"Code: 400"*)
	echo "Vault already initialised, continuing..."
	;;
*)
	echo "${vault_init_result}"
	;;
esac

configure_vault "helm/vault/scripts/" "${workspace}"

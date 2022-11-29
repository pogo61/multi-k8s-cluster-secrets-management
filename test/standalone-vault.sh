#!/usr/bin/env bash

# $WORKSPACE = The Terraform Workspace/K8s cluster environment
# $SIZE      = The cluster size
# $CLUSTER   = The name of the cluster (falls back to $WORKSPACE if empty)

set -eu

function deploy_helm() {
	local app_name="${1}"
	local path="test/helm/${1}"
	local namespace="${2}"
	local size="${3}"
#	chart=$(yq read "${image_file}" "${app_name}")
  chart="hashicorp/vault"

  printf "\n${GREEN}====== %s %s ======${RESET}\n" "installing" "${app_name}"

	(
		cd "${path}"
#		./generator.sh "${size}"
    gomplate -f standalone.tpl.yaml -o values.yaml
		helm upgrade --install "${app_name}" "${chart}" -f values.yaml --namespace "${namespace}" --cleanup-on-fail --wait  #--dry-run --debug
	)
}

function configure() {
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

function initialise() {
  GREEN=$'\e[1;32m'
  RESET=$'\e[0m'

  workspace=${1:-${WORKSPACE}}
  export WORKSPACE=${1}

  size=${2:-${SIZE}}
  image_file=${IMAGE_FILE:-${PWD}/image.yaml}

  if [ $# -ge 3 ]
  then
    vault_addr=${3}
    export VAULT_ADDR="$vault_addr"
  fi

  kubectx "$workspace"
}

initialise "$@"

configure "test/helm/consul/scripts/" "vault"
#deploy_helm "consul" "vault" "${size}"

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
	echo "error: ${vault_init_result}"
	;;
esac

configure "test/helm/vault/scripts/" "${workspace}"

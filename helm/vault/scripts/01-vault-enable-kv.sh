#!/usr/bin/env sh
echo "running 01-vault-enable-kv.sh"

# TODO: Move this to configuration via a separate TF project

# initialise vault to auto unseal it
#sleep 20s
#RESULT=$(kubectl -n vault exec -it vault-0 -- vault operator init -n 1 -t 1)
#ROOT_TOKEN="null"
#engineering_vault=""

#if [[ "$RESULT" == *"Vault is already initialized"* ]];
#then
#  :
#else
#  echo "{$RESULT}"
#
#  ROOT_TOKEN=$(echo "${RESULT}" | sed -n 's/Initial Root Token: \(.*\)/\1/p')
#  echo "${ROOT_TOKEN}"
#fi
#
## enable the kv secrets engine
VAULT_PODNAME=$(kubectl get pods -n vault -l app=vault -o jsonpath='{.items[*].metadata.name}' --field-selector=status.phase=Running | awk '{ print $1 }')
#echo VAULT_PODNAME is "${VAULT_PODNAME}"
#
#if [ "${ROOT_TOKEN}" != "null" ];
#then
#  vault kv put secret/vault/"${1}" root_token="${ROOT_TOKEN}"
#  engineering_vault="${VAULT_TOKEN}"
#  export VAULT_TOKEN="${ROOT_TOKEN}"
#else
#  engineering_vault="${VAULT_TOKEN}"
  export VAULT_TOKEN=$(vault kv get -field=root_token secret/vault/"${1}")
#fi

kubectl port-forward "${VAULT_PODNAME}" 8200:8200 -n vault &

sleep 10s
export VAULT_ADDR="http://localhost:8200"
vault secrets enable -version=2 -path=secret/ kv

PORT_PROCESS_ID="$(ps aux | grep kubectl | sed -n 1p | awk '{ print $2 }')"
kill -9 "${PORT_PROCESS_ID}"

#export VAULT_TOKEN="${engineering_vault}"
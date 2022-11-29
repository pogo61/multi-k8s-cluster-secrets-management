#!/usr/bin/env sh

echo "running 01-vault-enable-kv.sh"

VAULT_PODNAME=$(kubectl get pods -n vault -l app=vault -o jsonpath='{.items[*].metadata.name}' --field-selector=status.phase=Running | awk '{ print $1 }')

#kubectl port-forward "${VAULT_PODNAME}" 9200:8200 -n vault &

sleep 10s
vault_save="$VAULT_ADDR"
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="root"

#if [[ ${1} != "minikube" ]]
#then
#  export VAULT_TOKEN=$(vault kv get -field=root_token secret/vault/"${1}")
#else
#  export unseal_key=$(vault kv get -format=json secret/vault/"${1}" | jq -r .data.data.unseal_keys_hex[0])
#  export VAULT_TOKEN=$(vault kv get -field=root_token secret/vault/"${1}")
#fi

if [[ "${1}" != "minikube" ]]
then
  vault secrets enable -version=2 -path=secret/ kv
else
  vault operator unseal
  vault secrets disable secret/
  vault secrets enable -version=2 -path=secret/ kv
  unset unseal_key
fi

#echo ps aux | grep kubectl
#echo ps aux | grep kubectl | sed -n 1p |
#PORT_PROCESS_ID="$(ps aux | grep 9200:8200 | sed -n 2p | awk '{ print $2 }')"
#kill -9 "$(ps aux | grep 9200:8200 | sed -n 2p | awk '{ print $2 }')"

export VAULT_ADDR="$vault_save"

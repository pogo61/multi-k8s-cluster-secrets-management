#!/bin/bash -
echo "running 03-k8s-auth.sh"

source ./__helpers.sh ${1}

CLUSTER_FQN="minikube"
echo "CLUSTER_FQN is ${CLUSTER_FQN}"

SECRET_NAME="vault-acl"

K8S_HOST=${K8S_HOST:-"https://localhost:49916"}

K8S_CACERT="$(kubectl get secret "${SECRET_NAME}" -o jsonpath="{.data['ca\.crt']}" | base64 --decode)"
K8S_TOKEN="$(kubectl get secret "${SECRET_NAME}" -o jsonpath="{.data['token']}")"

VAULT_PODNAME="$(kubectl get pods -n $(namespace) -l app=vault -o jsonpath='{.items[*].metadata.name}' --field-selector=status.phase=Running | awk '{ print $1 }')"
echo "namespace is $(namespace)"
echo "VAULT_PODNAME is ${VAULT_PODNAME}"

#kubectl port-forward "${VAULT_PODNAME}" 9200:8200 -n $(namespace) &

sleep 1

vault_save="$VAULT_ADDR"
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="root"

# Enable the Kubernetes authentication method
vault auth enable kubernetes

# Configure Vault to talk to our Kubernetes host with the cluster's CA and the
# correct token reviewer JWT token
echo "K8S_HOST is ${K8S_HOST}"
echo "K8S_CACERT is ${K8S_CACERT}"
echo "K8S_TOKEN is ${K8S_TOKEN}"
#echo "TR_ACCOUNT_TOKEN is ${TR_ACCOUNT_TOKEN}"

vault write auth/kubernetes/config \
  kubernetes_host="${K8S_HOST}" \
  kubernetes_ca_cert="${K8S_CACERT}"
#  token_reviewer_jwt="${K8S_TOKEN}"

#PORT_PROCESS_ID="$(ps aux | grep 9200:8200 | sed -n 2p | awk '{ print $2 }')"
#kill -9 "${PORT_PROCESS_ID}"

export VAULT_ADDR="$vault_save"

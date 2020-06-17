#!/bin/bash -
echo "running 03-k8s-auth.sh"

source ./__helpers.sh ${1}

CLUSTER_FQN=$(gke-cluster-name "$(cluster-name ${1})")
echo "CLUSTER_FQN is ${CLUSTER_FQN}"

SECRET_NAME="$(kubectl get serviceaccount vault-acl \
  -o go-template='{{ (index .secrets 0).name }}')"

TR_ACCOUNT_TOKEN="$(kubectl get secret ${SECRET_NAME} \
  -o jsonpath={.data.token} | base64 --decode)"
#| awk '{$1=$1;print}'

#K8S_HOST="https://kubernetes.default.svc.cluster.local"
K8S_HOST=${K8S_HOST:-"https://kubernetes.default:443"}
#K8S_HOST="$(kubectl config view --raw \
#  -o go-template="{{ range .clusters }}{{ if eq .name \"${CLUSTER_FQN}\" }}{{ index .cluster \"server\" }}{{ end }}{{ end }}" | awk '{ print $1 }')"

K8S_CACERT="$(kubectl get secret "${SECRET_NAME}" -o jsonpath="{.data['ca\.crt']}" | base64 --decode)"

VAULT_PODNAME="$(kubectl get pods -n $(namespace) -l app=vault -o jsonpath='{.items[*].metadata.name}' --field-selector=status.phase=Running | awk '{ print $1 }')"
echo "namespace is $(namespace)"
echo "VAULT_PODNAME is ${VAULT_PODNAME}"
#K8S_HOST="http://$(kubectl get pod ${VAULT_PODNAME} -n $(namespace) -o jsonpath='{.status.hostIP}'| awk '{$1=$1;print}')"

kubectl port-forward "${VAULT_PODNAME}" 9200:8200 -n $(namespace) &

sleep 1

export VAULT_TOKEN=$(vault kv get -field=root_token secret/vault/"${1}")
vault_save="$VAULT_ADDR"
export VAULT_ADDR="http://localhost:9200"


# Enable the Kubernetes authentication method
vault auth enable kubernetes

# Configure Vault to talk to our Kubernetes host with the cluster's CA and the
# correct token reviewer JWT token
echo "K8S_HOST is ${K8S_HOST}"
echo "K8S_CACERT is ${K8S_CACERT}"
echo "TR_ACCOUNT_TOKEN is ${TR_ACCOUNT_TOKEN}"

vault write auth/kubernetes/config \
  kubernetes_host="${K8S_HOST}" \
  kubernetes_ca_cert="${K8S_CACERT}" #\
#  token_reviewer_jwt="${TR_ACCOUNT_TOKEN}"


PORT_PROCESS_ID="$(ps aux | grep kubectl | sed -n 1p | awk '{ print $2 }')"
kill -9 "${PORT_PROCESS_ID}"

export VAULT_ADDR="$vault_save"
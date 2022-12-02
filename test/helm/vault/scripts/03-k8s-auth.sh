#!/bin/bash -
echo "running 03-k8s-auth.sh"

source ./__helpers.sh ${1}

if [[ "${1}" != "minikube" ]]
then
  CLUSTER_FQN="$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')"
else
  CLUSTER_FQN=("https://$(kubectl exec vault-0 -n vault -- sh -c 'echo $KUBERNETES_SERVICE_HOST'):$(kubectl exec vault-0 -n vault -- sh -c 'echo $KUBERNETES_SERVICE_PORT')")
fi
echo "CLUSTER_FQN is ${CLUSTER_FQN}"

K8S_CACERT=$(kubectl get secret \
   $(kubectl get serviceaccount vault-acl -o jsonpath='{.secrets[0].name}') \
   -o jsonpath='{ .data.ca\.crt }' | base64 --decode)
TOKEN_REVIEW_JWT=$(kubectl get secret \
   $(kubectl get serviceaccount vault-acl -o jsonpath='{.secrets[0].name}') \
   -o jsonpath='{ .data.token }' | base64 --decode)

sleep 1

vault_save="$VAULT_ADDR"
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="root"
export CLUSTER_NAME="kubernetes"

# Enable the Kubernetes authentication method
vault auth enable -path=$CLUSTER_NAME kubernetes


# Configure Vault to talk to our Kubernetes host with the cluster's CA and the
# correct token reviewer JWT token
echo "CLUSTER_FQN is ${CLUSTER_FQN}"
echo "K8S_CACERT is ${K8S_CACERT}"
echo "TOKEN_REVIEW_JWT is ${TOKEN_REVIEW_JWT}"

vault write auth/$CLUSTER_NAME/config \
  kubernetes_host="${CLUSTER_FQN}" \
  kubernetes_ca_cert="${K8S_CACERT}"  \
  token_reviewer_jwt="${TOKEN_REVIEW_JWT}" \
  issuer="kubernetes/serviceaccount"

export VAULT_ADDR="$vault_save"

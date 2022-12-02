#!/bin/bash -

# change this from minikube to kubernetes if running on anyting other than minikube
export CLUSTER_NAME="kubernetes"

# create a test secret
echo "abcd1234" | vault kv put -mount=secret test/data token=-

# define the service account that will be authorised to access Vault
vault write auth/$CLUSTER_NAME/role/cf-test \
    bound_service_account_names="vault-acl" \
    bound_service_account_namespaces="default" \
    policies="runtime_vault-kv,runtime_vault-auth" \
    token_policies="runtime_vault-kv,runtime_vault-auth" \
    ttl=24h

kubectl apply -f test/deployment.yaml
kubectl apply -f test/role.yaml
kubectl apply -f test/roleBinding.yaml

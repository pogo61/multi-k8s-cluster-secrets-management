#!/bin/bash -

# create a test secret
#vault kv put secret/data/exampleapp/config \
#  token="${vault_root}"

# define the service account that will be authorised to access Vault
vault write auth/kubernetes/role/cf-test \
    bound_service_account_names="vault-acl" \
    bound_service_account_namespaces="default" \
    policies="runtime_vault-kv,runtime_vault-auth" \
    token_policies="runtime_vault-kv,runtime_vault-auth" \
    ttl=24h

kubectl apply -f kubernetes/deployment.yaml
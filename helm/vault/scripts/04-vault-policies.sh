#!/bin/bash -
set -Eeuo pipefail
echo "running 04-vault-policies.sh"``

# TODO: Move this to configuration via a separate TF project

source ./__helpers.sh ${1}

namespace="${1}"

VAULT_PODNAME=$(kubectl get pods -n $(namespace) -l app=vault -o jsonpath='{.items[*].metadata.name}' --field-selector=status.phase=Running | awk '{ print $1 }')

kubectl port-forward "${VAULT_PODNAME}" 8200:8200 -n $(namespace) &

sleep 1

export VAULT_TOKEN=$(vault kv get -field=root_token secret/vault/"${1}")
export VAULT_ADDR="http://localhost:8200"


vault policy write runtime_vault-kv - <<EOH
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write runtime_vault-auth - <<EOH
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault write auth/kubernetes/role/runtime_vault-role \
  bound_service_account_names="vault-acl" \
  bound_service_account_namespaces="default" \
  policies="runtime_vault-kv,runtime_vault-auth" \
  ttl="24h"


vault policy write admin-auth - <<EOH
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-sys-auth - <<EOH
path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}
EOH

vault policy write admin-sys-policy - <<EOH
path "sys/policy" {
  capabilities = ["read", "list"]
}
EOH

vault policy write admin-sys-policy-all - <<EOH
path "sys/policy/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-sys-policy-acl - <<EOH
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-entity - <<EOH
path "identity/entity" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-entity-all - <<EOH
path "identity/entity/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-entity-alias - <<EOH
path "identity/entity-alias/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-leases - <<EOH
path "sys/leases/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-groups - <<EOH
path "identity/group" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-groups-all - <<EOH
path "identity/group/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-groups-alias - <<EOH
path "identity/group-alias/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-secret-engines - <<EOH
path "sys/mounts" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-secret-engines-all - <<EOH
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-secrets - <<EOH
path "secret/" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-secrets-all - <<EOH
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-secrets-data-all - <<EOH
path "secret/data/*"{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-mongo-platform - <<EOH
path "secret/data/mongodb/platform"{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-mongo-uat - <<EOH
path "secret/data/mongodb/uat"{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-mongo-engage - <<EOH
path "secret/data/mongodb/engage"{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-mongo-rocket - <<EOH
path "secret/data/mongodb/rocket"{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-mongo-iceberg - <<EOH
path "secret/data/mongodb/iceberg"{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-mongo-integrations - <<EOH
path "secret/data/mongodb/integrations"{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-secret-metadata - <<EOH
path "secret/metadata/*"{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOH

vault policy write admin-gcp-secrets - <<EOH
path "gcp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-gcp-secrets-keys - <<EOH
path "gcp/key/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-gcp-secrets-tokens - <<EOH
path "gcp/token/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-aws-secrets - <<EOH
path "aws/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-aws-secrets-roles - <<EOH
path "aws/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

vault policy write admin-health-checks - <<EOH
path "sys/health" {
  capabilities = ["read", "sudo"]
}
EOH

vault policy write admin-capabilities - <<EOH
path "sys/capabilities" {
  capabilities = ["create", "update"]
}
EOH

vault policy write admin-capabilities-self - <<EOH
path "sys/capabilities-self" {
  capabilities = ["create", "update"]
}
EOH

vault policy write admin-capabilities-accessor - <<EOH
path "sys/capabilities-accessor" {
  capabilities = ["create", "update"]
}
EOH

vault write auth/kubernetes/role/admin-role \
  bound_service_account_names="default" \
  bound_service_account_namespaces="default" \
  policies="default,admin-auth,admin-sys-auth,admin-sys-policy,admin-sys-policy-all,admin-sys-policy-acl,admin-entity,\
  admin-entity-all,admin-entity-alias,admin-leases,admin-groups,admin-groups-all,admin-groups-alias,\
  admin-secret-engines,admin-secret-engines-all,admin-secrets,admin-secrets-all,admin-secrets-data-all,\
  admin-mongo-platform,admin-mongo-uat,admin-mongo-engage,admin-mongo-rocket,admin-mongo-iceberg,\
  admin-mongo-integrations,admin-secret-metadata,admin-gcp-secrets,admin-gcp-secrets-keys,admin-gcp-secrets-tokens,\
  admin-aws-secrets,admin-aws-secrets-roles,admin-health-checks,admin-capabilities,\
  admin-capabilities-self,admin-capabilities-accessor" \
  ttl="15m"

vault policy write infra-dev-auth-token-create - <<EOH
path "auth/token/create" {
  capabilities = [ "update" ]
}
EOH

vault policy write infra-dev-secret-data-iam - <<EOH
path "secret/data/iam" {
  capabilities = ["read", "list"]
}
EOH

vault policy write infra-dev-secret-data-zerotier-toolbox-all - <<EOH
path "secret/data/zerotier/toolbox/*" {
  capabilities = ["read", "list", "create"]
}
EOH

vault policy write infra-dev-aws - <<EOH
path "aws" {
  capabilities = ["read", "list"]
}
EOH

vault policy write infra-dev-aws-creds - <<EOH
path "aws/creds" {
  capabilities = ["read", "list"]
}
EOH

vault policy write infra-dev-aws-creds-k8s-cluster - <<EOH
path "aws/creds/k8s-cluster" {
  capabilities = ["read", "list"]
}
EOH

vault write auth/kubernetes/role/infra-dev-role \
  bound_service_account_names="default" \
  bound_service_account_namespaces="default" \
  policies="infra-dev-auth-token-create,infra-dev-secret-data-iam,infra-dev-secret-data-zerotier-toolbox-all,\
  infra-dev-aws,infra-dev-aws-creds,infra-dev-aws-creds-k8s-cluster" \
  ttl="15m"

PORT_PROCESS_ID="$(ps aux | grep kubectl | sed -n 1p | awk '{ print $2 }')"
kill -9 "${PORT_PROCESS_ID}"
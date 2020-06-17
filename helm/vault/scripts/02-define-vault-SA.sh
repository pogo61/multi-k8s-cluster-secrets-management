#!/bin/bash -
set -Eeuo pipefail
echo "running 02-define-vault-SA.sh"

source ./__helpers.sh ${1}

VAULT_ACL_RELEASE=$(vault-release)-acl

helm upgrade --install ${VAULT_ACL_RELEASE} \
  ../../vault-acl/ \
  -f "../../vault-acl/vault-acl-values.yaml" \
  --namespace "default" \
	--cleanup-on-fail

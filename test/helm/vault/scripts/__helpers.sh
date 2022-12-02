# google-project returns the name of the current project, accounting for a
# variety of common environments. If no project is found in any of the common
# places, an error is returned.
google-project() {
  (
    echo "${PROJECT:-k8s-staging}"
  )
}

# gke-cluster-name is the name of the cluster for the given suffix.
gke-cluster-name() {
  (
    set -Eeuo pipefail

    echo "gke_$(google-project)_$(google-region)_${1}"
  )
}

# gke-latest-master-version returns the latest GKE master version.
gke-latest-master-version() {
  (
    set -Eeuo pipefail

    gcloud container get-server-config \
      --project="$(google-project)" \
      --region="$(google-region)" \
      --format='value(validMasterVersions[0])' \
      2>/dev/null
  )
}

# google-region returns the region in which resources should be created. This
# variable must be changed before running any commands.
google-region() {
  (
    echo "europe-west4"
  )
}

vault-service-account() {
  (
    echo "vault"
  )
}

vault-service-account-email() {
  (
    echo "$(vault-service-account)@$(google-project).iam.gserviceaccount.com"
  )
}

keyring() {
  (
    echo "vault-helm-unseal-kr"
  )
}

key() {
  (
    echo "vault-helm-unseal-key"
  )
}

cluster-name() {
  (
    local cluster_name="${1}"
    if [ -z "${cluster_name:-}" ]; then
      echo "vault-on-kubernetes"
      return 0
    fi
    echo "${cluster_name}"
  )
}

namespace() {
  (
    echo "vault"
  )
}

consul-release() {
  (
    echo "consul"
  )
}

vault-release() {
  (
    echo "vault"
  )
}
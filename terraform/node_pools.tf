locals {
  oauth_scopes = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/devstorage.read_write",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/trace.append",
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}

data "google_service_account" "node_pool" {
  account_id = "k8s-cluster"
}

resource "google_container_node_pool" "vault" {
  count       = var.node_pools["vault"]["count"]
  name_prefix = "vault-"
  cluster     = google_container_cluster.k8s.name
  location    = local.region
  node_count  = var.node_pools["vault"]["node_count"]

  provider = google-beta

  node_config {
    machine_type    = var.node_pools["vault"]["machine_type"]
    service_account = data.google_service_account.node_pool.email
    taint {
      effect = "NO_SCHEDULE"
      key    = "group"
      value  = "vault"
    }

    labels = {
      node-type = "vault"
      project   = local.project
      region    = local.region
    }

    oauth_scopes = local.oauth_scopes
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_container_node_pool" "consul" {
  count       = var.node_pools["consul"]["count"]
  name_prefix = "consul-"
  cluster     = google_container_cluster.k8s.name
  location    = local.region
  node_count  = var.node_pools["consul"]["node_count"]

  provider = google-beta

  node_config {
    machine_type    = var.node_pools["consul"]["machine_type"]
    service_account = data.google_service_account.node_pool.email
    taint {
      effect = "NO_SCHEDULE"
      key    = "group"
      value  = "consul"
    }

    labels = {
      node-type = "consul"
      project   = local.project
      region    = local.region
    }

    oauth_scopes = local.oauth_scopes
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  lifecycle {
    create_before_destroy = true
  }
}

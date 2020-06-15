terraform {
  required_version = "~> 0.12"
  backend "gcs" {
    bucket = "k8s-terraform"
    prefix = "terraform/k8s-cluster"
  }
}

provider "vault" {
  address = "https://vault.global.k8s.master"
}

provider "google" {
  credentials = local.credentials
  project     = local.project
  region      = local.region
  version     = "2.20.2"
}

provider "google-beta" {
  credentials = local.credentials
  project     = local.project
  region      = local.region
  version     = "2.20.2"
}

locals {
  credentials = base64decode(data.vault_generic_secret.iam.data["terraform"])

  names = {
    staging           = "k8s-cluster"
    test              = "k8s-cluster"
    production        = "k8s-cluster"
  }

  projects = {
    staging           = "k8s-staging"
    test              = "k8s-test"
    production        = "k8s-production"
  }

  managed_zones = {
    staging           = "k8s.com"
    test              = "k8s.com"
    production        = "k8s.com"
  }

  subdomains = {
    staging           = "staging."
    test              = "test."
    production        = ""
  }

  regions = {
    test              = "us-west1"
    production        = "us-east1"
    staging           = "us-east1"
  }

  app_engine_regions = {
    k8s-staging    = "us-east1"
    k8s-test       = "us-east1"
    k8s-production = "us-east1"
  }

  project                 = lookup(local.projects, terraform.workspace, "k8s-staging")
  managed_zone            = lookup(local.managed_zones, terraform.workspace, "k8s")
  trimmed_subdomain       = replace(local.subdomain, "/[.]$/", "")
  subdomain               = lookup(local.subdomains, terraform.workspace, "${terraform.workspace}.")
  region                  = lookup(local.regions, terraform.workspace, "europe-west4")
  app_engine_region       = lookup(local.app_engine_regions, local.project, "europe-west1")
  name                    = lookup(local.names, terraform.workspace, terraform.workspace)
}

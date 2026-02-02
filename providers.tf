# =============================================================================
# Provider Configuration
# =============================================================================
# This template uses the rancher2 provider to register custom RKE2 clusters
# in Rancher Server. VMs are provisioned directly using Hetzner Cloud provider.
# =============================================================================

terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "13.1.4"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.59"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.0"
}

# Rancher Provider
# Authenticates to Rancher Server API to manage clusters
provider "rancher2" {
  api_url   = var.rancher_api_url
  token_key = var.rancher_api_token
  insecure  = var.rancher_insecure
}

# Hetzner Cloud Provider
# Required for SSH key management (used in node templates)
provider "hcloud" {
  token = var.hcloud_token
}

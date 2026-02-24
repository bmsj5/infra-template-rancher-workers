# =============================================================================
# Variables
# =============================================================================
# This template supports provisioning N downstream RKE2 clusters (cells) via
# Rancher Server. Each cell is defined with its own configuration including
# region, labels, and node pool settings.
# =============================================================================

# -----------------------------------------------------------------------------
# Rancher API Configuration
# -----------------------------------------------------------------------------
variable "rancher_api_url" {
  description = "Rancher Server API URL (e.g., https://rancher.yourdomain.com)"
  type        = string
  validation {
    condition     = can(regex("^https?://", var.rancher_api_url))
    error_message = "Rancher API URL must start with http:// or https://"
  }
}

variable "rancher_api_token" {
  description = "Rancher API token with cluster management permissions"
  type        = string
  sensitive   = true
}

variable "rancher_insecure" {
  description = "Allow insecure TLS connections to Rancher API (use only for self-signed certs)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Cloud Provider Credentials
# -----------------------------------------------------------------------------
variable "hcloud_token" {
  description = "Hetzner Cloud API token (required for SSH key management in node templates)"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# SSH Configuration
# -----------------------------------------------------------------------------
variable "ssh_key_path" {
  description = "Path to the local SSH public key to use in node templates"
  type        = string
  validation {
    condition     = fileexists(pathexpand(var.ssh_key_path))
    error_message = "SSH public key file must exist"
  }
}

variable "ssh_key_name" {
  description = "SSH key name that will be created in the cloud security storage"
  type        = string
}

# -----------------------------------------------------------------------------
# Cluster Configuration
# -----------------------------------------------------------------------------
variable "rke2_version" {
  description = "RKE2 version to install (e.g., v1.34.2+rke2r1). Must match Rancher support matrix."
  type        = string
  default     = "v1.34.2+rke2r1"
  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+\\+rke2r[0-9]+$", var.rke2_version))
    error_message = "RKE2 version must be in format vX.Y.Z+rke2rN (e.g., v1.34.2+rke2r1)"
  }
}


variable "node_count_per_cell" {
  description = "Number of nodes per cell (must be >= 3 for HA)"
  type        = number
  default     = 3
  validation {
    condition     = var.node_count_per_cell >= 3
    error_message = "Node count per cell must be at least 3 for HA RKE2 cluster"
  }
}

# -----------------------------------------------------------------------------
# Cell Definitions
# -----------------------------------------------------------------------------
# Each cell represents a downstream RKE2 cluster with its own configuration.
# Labels are parsed from the cell definition and applied to the cluster.
variable "cells" {
  description = "List of cell definitions. Each cell will create a separate RKE2 cluster."
  type = map(object({
    region         = string
    labels         = map(string)
    node_count     = optional(number, 3)
    server_type    = optional(string, "cx33")
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.cells : contains([
        "fsn1", "nbg1", "hel1", "ash", "hil"
      ], v.region)
    ])
    error_message = "Region must be one of: fsn1, nbg1, hel1, ash, hil"
  }

  validation {
    condition = alltrue([
      for k, v in var.cells : v.node_count >= 3
    ])
    error_message = "Node count per cell must be at least 3 for HA"
  }
}

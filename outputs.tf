# =============================================================================
# Outputs
# =============================================================================
# These outputs provide information about the provisioned clusters and VMs.
# Useful for integration with CI/CD pipelines and Fleet targeting.
# =============================================================================

output "clusters" {
  description = "Map of all provisioned clusters with their details"
  value = {
    for k, cluster in rancher2_cluster.cells : k => {
      name               = cluster.name
      kubeconfig         = cluster.kube_config
      labels             = cluster.labels
      kubernetes_version = var.rke2_version
      leader_ip          = hcloud_server.cell_nodes["${k}-0"].ipv4_address
    }
  }
  sensitive = true
}

output "nodes" {
  description = "Map of all provisioned VMs by cluster and node index"
  value = {
    for k, node in hcloud_server.cell_nodes : k => {
      name       = node.name
      ipv4       = node.ipv4_address
      ipv6       = node.ipv6_address
      cluster    = local.cell_nodes[k].cell_key
      region     = node.location
      server_type = node.server_type
    }
  }
}

output "summary" {
  description = "Summary of provisioned infrastructure"
  value = {
    total_clusters = length(var.cells)
    total_nodes    = length(hcloud_server.cell_nodes)
    rke2_version   = var.rke2_version
  }
}

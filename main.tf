# =============================================================================
# Infrastructure Template - Rancher Worker Clusters (Downstream Cells)
# =============================================================================
# This template provisions downstream RKE2 clusters via Rancher Server.
# Each cell is a separate HA RKE2 cluster with labels for Fleet targeting.
#
# Architecture:
# - Provisions Hetzner Cloud VMs directly using hcloud_server
# - Bootstraps RKE2 clusters manually (leader + followers)
# - Registers clusters in Rancher as custom clusters
# - Applies cluster labels for Fleet targeting
# =============================================================================

# -----------------------------------------------------------------------------
# SSH Key Management
# -----------------------------------------------------------------------------
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.ssh_key_path)
}

# Hetzner Cloud SSH Key
resource "hcloud_ssh_key" "default" {
  name       = var.ssh_key_name
  public_key = data.local_file.ssh_public_key.content
}

# -----------------------------------------------------------------------------
# RKE2 Cluster Tokens (One per cell)
# -----------------------------------------------------------------------------
resource "random_password" "rke2_token" {
  for_each = var.cells

  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# -----------------------------------------------------------------------------
# GKE-style kubelet system-reserved CPU (by server type vCPU count)
# -----------------------------------------------------------------------------
# The formula: 1->60m, 2->70m, 3->75m, 4->80m, 5+->80+floor((n-4)*2.5)m
locals {
  server_type_cpus = {
    "cx23" = 2
    "cx33" = 4
    "cx43" = 8
    "cx53" = 16
    "cpx22" = 2
    "cpx32" = 4
    "cpx42" = 8
    "cpx52" = 16
    "cpx62" = 32
    "ccx13" = 2
    "ccx23" = 4
    "ccx33" = 8
    "ccx43" = 16
    "ccx53" = 32
    "ccx63" = 64
  }
  reserved_cpu_m = {
    for k, c in local.server_type_cpus : k => (
      c == 1 ? 60 : (c == 2 ? 70 : (c == 3 ? 75 : (c == 4 ? 80 : 80 + floor((c - 4) * 2.5))))
    )
  }
}

# -----------------------------------------------------------------------------
# Hetzner Cloud VMs (One per cell, multiple nodes per cell)
# -----------------------------------------------------------------------------
# Create a flattened map: cell_key -> node_index
locals {
  cell_nodes = merge([
    for cell_key, cell in var.cells : {
      for node_idx in range(coalesce(cell.node_count, var.node_count_per_cell)) :
      "${cell_key}-${node_idx}" => {
        cell_key   = cell_key
        node_index = node_idx
        cell       = cell
      }
    }
  ]...)
}

resource "hcloud_server" "cell_nodes" {
  for_each = local.cell_nodes

  name        = "${each.value.cell_key}-node-${each.value.node_index + 1}"
  image       = "debian-13"
  server_type = each.value.cell.server_type
  location    = each.value.cell.region
  ssh_keys    = [hcloud_ssh_key.default.id]

  user_data = templatefile("${path.module}/templates/user-data.yaml.tpl", {
    node_index       = each.value.node_index
    node_count       = coalesce(each.value.cell.node_count, var.node_count_per_cell)
    cluster_token    = random_password.rke2_token[each.value.cell_key].result
    node_hostname    = "${each.value.cell_key}-node-${each.value.node_index + 1}"
    ssh_public_key   = data.local_file.ssh_public_key.content
    rke2_version     = var.rke2_version
    reserved_cpu_m   = local.reserved_cpu_m[each.value.cell.server_type]
  })

}

# -----------------------------------------------------------------------------
# Wait for Cluster Stability Before Follower Updates
# -----------------------------------------------------------------------------
resource "null_resource" "wait_for_clusters_stability" {
  depends_on = [hcloud_server.cell_nodes]

  provisioner "local-exec" {
    command = "echo '⏳ Waiting 60 seconds for leader nodes to stabilize...' && sleep 60"
  }
}

# -----------------------------------------------------------------------------
# Configure Follower Nodes to Join Clusters
# -----------------------------------------------------------------------------
resource "null_resource" "configure_follower_nodes" {
  for_each = {
    for k, v in local.cell_nodes : k => v
    if v.node_index > 0  # Skip leader nodes (index 0)
  }

  depends_on = [null_resource.wait_for_clusters_stability]

  connection {
    type        = "ssh"
    host        = hcloud_server.cell_nodes[each.key].ipv4_address
    user        = "root"
    private_key = file(pathexpand(replace(var.ssh_key_path, ".pub", "")))
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Configuring follower node ${each.value.cell_key}-node-${each.value.node_index + 1}...'",
      "LEADER_IP=${hcloud_server.cell_nodes["${each.value.cell_key}-0"].ipv4_address}",
      "echo \"Leader IP: $LEADER_IP\"",
      "echo \"server: https://$LEADER_IP:9345\" >> /etc/rancher/rke2/config.yaml",
      "systemctl enable --now rke2-server",
      "export PATH=$PATH:/var/lib/rancher/rke2/bin",
      "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml",
      "until kubectl get node ${each.value.cell_key}-node-${each.value.node_index + 1} >/dev/null 2>&1; do sleep 2; done",
      "kubectl label node ${each.value.cell_key}-node-${each.value.node_index + 1} node-role.kubernetes.io/worker=true",
      "echo 'Follower node configured and joining cluster'"
    ]
  }

  triggers = {
    leader_ip   = hcloud_server.cell_nodes["${each.value.cell_key}-0"].ipv4_address
    follower_id = hcloud_server.cell_nodes[each.key].id
  }
}

# -----------------------------------------------------------------------------
# Register Existing RKE2 Clusters in Rancher
# -----------------------------------------------------------------------------
resource "rancher2_cluster" "cells" {
  for_each = var.cells

  name        = each.key
  description = "Imported RKE2 cluster ${each.key}"

  labels = each.value.labels

  rke2_config {
    version = var.rke2_version
  }
}

# -----------------------------------------------------------------------------
# Apply Rancher import manifest on leader node (per cluster)
# -----------------------------------------------------------------------------
resource "null_resource" "register_clusters" {
  for_each = var.cells

  depends_on = [
    rancher2_cluster.cells,
    null_resource.configure_follower_nodes
  ]

  connection {
    type        = "ssh"
    host        = hcloud_server.cell_nodes["${each.key}-0"].ipv4_address
    user        = "root"
    private_key = file(pathexpand(replace(var.ssh_key_path, ".pub", "")))
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/var/lib/rancher/rke2/bin",
      "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml",
      "curl -sfL ${rancher2_cluster.cells[each.key].cluster_registration_token[0].manifest_url} | kubectl apply -f -"
    ]
  }

  triggers = {
    cluster_id   = rancher2_cluster.cells[each.key].id
    manifest_url = rancher2_cluster.cells[each.key].cluster_registration_token[0].manifest_url
    leader_ip    = hcloud_server.cell_nodes["${each.key}-0"].ipv4_address
  }
}

# Infrastructure Template - Rancher Worker Clusters (Downstream Cells)

Reusable Terraform/OpenTofu template for provisioning downstream RKE2 HA clusters via Rancher Server. Each "cell" is a separate RKE2 cluster with configurable labels for Fleet targeting.

**⚠️ TEMPLATE ONLY** - Copy and customize before use.

⚠️ This template provisions downstream clusters managed by an existing Rancher Server. Ensure your Rancher management cluster is operational before using this template.

## Current Configuration

- **Purpose:** Downstream RKE2 Worker Clusters (Cells)
- **Cloud Provider:** Hetzner Cloud
- **Kubernetes:** RKE2 (HA, 3+ nodes per cell)
- **CNI:** Cilium
- **Management:** Rancher Server (existing, used to register/import clusters)
- **Labels:** Configurable per cell for Fleet targeting

⚠️ This template uses the Rancher2 Terraform provider to **register** self‑provisioned RKE2 clusters in Rancher (import/registered cluster flow). It's currently vendor-specific (Hetzner + Cloudflare). To use other providers, you will have to change the code significantly.

## Architecture

This template supports provisioning **N cells** (downstream clusters). Each cell:
- Is a separate HA RKE2 cluster (leader + followers)
- Is provisioned directly on Hetzner Cloud using `hcloud_server`
- Bootstraps RKE2 via cloud‑init (leader) and SSH join (followers)
- Is **registered/imported** into Rancher as an existing RKE2 cluster
- Has configurable labels (app, region, cluster_id, deployment_env, hub, etc.)
- Can be targeted by Rancher Fleet using label selectors
- Supports independent scaling and configuration

### Example Cell Configuration

```hcl
cells = {
  "germany-cluster-1" = {
    region      = "nbg1"
    node_count  = 3
    server_type = "cx23"
    labels = {
      app            = "skies-dota"
      region         = "germany"
      cluster_id     = "1"
      deployment_env = "development"
      hub            = "true"
    }
  }
  "finland-cluster-1" = {
    region      = "fsn1"
    node_count  = 3
    server_type = "cx23"
    labels = {
      app            = "skies-dota"
      region         = "finland"
      cluster_id     = "2"
      deployment_env = "development"
      hub            = "false"
    }
  }
}
```

## RKE2 Version Compatibility

**Rancher 2.13.x supports:**
- RKE2 v1.34.x (latest supported: `v1.34.2+rke2r1`)

**Current default:** `v1.34.2+rke2r1` (compatible with Rancher 2.13.x)

Check [Rancher's support matrix](https://rancher.com/support-matrix/) for the latest compatibility information.

## Prerequisites

**Tools:**
- OpenTofu >= 1.0 (or Terraform >= 1.0)
- `jq` (for Makefile)

**External Dependencies:**
- Existing Rancher Server (management cluster) running and accessible - see [infra-template-rancher-management](https://github.com/bmsj5/infra-template-rancher-management) for setup

**Credentials:**
- SSH key pair
- Cloud provider API token
- Rancher API token with cluster management permissions (the Bearer Token)

## Quick Start

1. **Copy template:**
```bash
cp -r infra-template-rancher-workers your-repo-name
cd your-repo-name
```

2. **Set API tokens (mandatory):**
```bash
export TF_VAR_hcloud_token="your-hetzner-token"
export TF_VAR_rancher_api_token="your-rancher-api-token"
```

3. **Configure variables:**
   Copy/Rename to "terraform.tfvars" and customize this file [`terraform.tfvars.example`](terraform.tfvars.example) for your environment:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```
   See [`variables.tf`](variables.tf) for a complete list of available variables.

4. **Review the Makefile:**
   Check [`Makefile`](Makefile) to see available commands. Key targets include infrastructure management (`init`, `plan`, `apply`, `destroy`) and information display (`info`).

5. **Deploy infrastructure:**
```bash
make init
make plan
make apply
```

## Makefile Targets

### Infrastructure Management
- `make init` - Initialize Terraform/OpenTofu
- `make plan` - Preview changes (runs with `-lock=false`)
- `make apply` - Deploy infrastructure (runs with `-auto-approve -lock=false`)
- `make destroy` - Destroy infrastructure (runs with `-auto-approve -lock=false`)

## Fleet Targeting

Clusters are automatically labeled with the values from your cell definitions. Use these labels in Fleet GitOps repositories:

```yaml
# Example: services/skiesdota-tg-bot/fleet.yaml
targets:
  - name: germany
    clusterSelector:
      matchLabels:
        region: germany
        app: skies-dota
  - name: finland
    clusterSelector:
      matchLabels:
        region: finland
        app: skies-dota
```

## Outputs

All outputs are exported to `.terraform-outputs.json` and automatically set in Ansible playbooks via the Makefile.

See [`outputs.tf`](outputs.tf) for a complete list of available outputs.

## Support

- [Rancher Docs](https://ranchermanager.docs.rancher.com)
- [RKE2 Docs](https://docs.rke2.io)
- [Rancher Support Matrix](https://rancher.com/support-matrix/)
- [Hetzner Cloud Docs](https://docs.hetzner.cloud)
- [OpenTofu Docs](https://opentofu.org)

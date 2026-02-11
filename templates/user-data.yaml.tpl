#cloud-config

hostname: ${node_hostname}

packages:
  - curl
  - git
  - htop

ssh_authorized_keys:
  - ${ssh_public_key}

write_files:
  # RKE2 base configuration
  - path: /etc/rancher/rke2/config.yaml
    content: |
      token: "${cluster_token}"
      tls-san:
        - 127.0.0.1
        - localhost
      cni: [cilium]
      disable:
        - rke2-ingress-nginx
        - rke2-snapshot-controller
        - rke2-snapshot-validation-webhook
      kubelet-arg:
        - cpu-manager-policy=static
        - system-reserved=cpu=${reserved_cpu_m}m
%{ if node_index == 0 }
      cluster-init: true
%{ endif }

runcmd:
  - echo "Installing RKE2 on ${node_hostname}..."
  - curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="${rke2_version}" sh -
%{ if node_index == 0 }
  - systemctl enable rke2-server
  - systemctl start rke2-server
  - echo "RKE2 leader node started on ${node_hostname}"
  - export PATH=$PATH:/var/lib/rancher/rke2/bin
  - export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
  - until kubectl get nodes ${node_hostname} 2>/dev/null | grep -q Ready; do sleep 2; done
  - kubectl label node ${node_hostname} node-role.kubernetes.io/worker=true
%{ else }
  - echo "RKE2 follower node installed on ${node_hostname} - waiting for join configuration"
%{ endif }

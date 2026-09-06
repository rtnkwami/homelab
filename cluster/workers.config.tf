locals {
  worker_config = {
    # Generate a machine config for each autoscaling group configured for cluster autoscaler
    for pool in local._autoscaler_nodepools : pool.name => [{
      machine = {
        kubelet = {
          extraConfig = {
            registerWithTaints = pool.taints
          }
          # NOTE:
          # if this isn't set on worker nodes, kubelet on worker nodes will
          # try to reach kube-dns on the hardcoded original config which would
          # cause them to timeout with an old ip.
          clusterDNS = [cidrhost(local.network_config.cidrs.k8s_services, 10)]
          extraArgs = {
            cloud-provider = "external"
          }
        }
        nodeLabels = pool.labels
      }
    }]
  }
}

data "talos_machine_configuration" "worker" {
  for_each = { for pool in local._autoscaler_nodepools : pool.name => pool }
  
  cluster_name = "homelab"
  machine_type = "worker"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${local.controlplane.ip.private}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = [for config in local.worker_config[each.key] : yamlencode(config)]
}
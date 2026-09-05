locals {
  worker_config = {
    machine = {
      kubelet = {
        extraConfig = {
          registerWithTaints = [
            {
              key    = "node.niovial.io/pool"
              value  = "system"
              effect = "NoSchedule"
            }
          ]
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
      nodeLabels = {
        "node.niovial.io/pool" = "system"
      }
    }
  }
}

data "talos_machine_configuration" "worker" {
  cluster_name = "homelab"
  machine_type = "worker"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${local.controlplane.ip.private}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = [yamlencode(local.worker_config)]
}
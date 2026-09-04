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

resource "talos_machine_configuration_apply" "worker" {
  for_each = hcloud_server.worker

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  # public ip needed, otherwise tofu can't reach nodes
  node = each.value.ipv4_address
}
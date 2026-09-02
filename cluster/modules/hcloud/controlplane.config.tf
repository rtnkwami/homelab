locals {
  cluster_endpoint = "https://${hcloud_load_balancer_network.controlplane.ip}:6443"
  
  controlplane_config = {
    machine = {
      kubelet = {
        # extraArgs = {
        #   cloud-provider             = "external"
        #   rotate-server-certificates = true
        # }
        clusterDNS = [cidrhost(local.pod_net.service_cidr, 10)]
      }
    }
    cluster = {
      network = {
        podSubnets = [local.pod_net.pod_cidr]
        serviceSubnets = [local.pod_net.service_cidr]
      }
      controllerManager = {
        extraArgs = {
          "node-cidr-mask-size-ipv4" = "26"
        }
      }
    }
  }
}

# Step 1: Generate secrets for etcd, kube-apiserver, etc. among others
resource "talos_machine_secrets" "this" {}

# Step 2: Create machine config that will allow control plane nodes to find each other
data "talos_machine_configuration" "controlplane" {
  cluster_name = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_secrets = talos_machine_secrets.this.machine_secrets
  kubernetes_version = local.versions.k8s
  talos_version = local.versions.talos
  machine_type = "controlplane"
  config_patches = [yamlencode(local.controlplane_config)]
}

resource "talos_machine_configuration_apply" "this" {
  for_each = hcloud_server.controlplane

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node = each.value.ipv4_address
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.this]

  # needs to be a public ip otherwise runner can't actually reach bootstrap node
  node = hcloud_server.controlplane[local.hcloud_zones[0]].ipv4_address
  client_configuration = talos_machine_secrets.this.client_configuration
}
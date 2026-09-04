locals {
  controlplane = {
    ip = {
      public = hcloud_load_balancer.this.ipv4
      private = hcloud_load_balancer_network.this.ip
    }
    bootstrap_node = hcloud_server.controlplane[local.hcloud_zones[0]]
  }

  controlplane_config = {
    machine = {
      certSANs = [local.controlplane.ip.public]
      kubelet = {
        # NOTE: 
        # Replace default network config with actual configured networking and subnets, as
        # network segregation needs to be implemented
        clusterDNS = [cidrhost(local.network_config.cidrs.k8s_services, 10)]
      }
    }
    cluster = {
      network = {
        podSubnets = [local.network_config.cidrs.k8s_pods]
        serviceSubnets = [local.network_config.cidrs.k8s_services]
      }
      apiServer = {
        # NOTE:
        # For k8s components, such as kubelet, controller manager, etcd, local.private_cluster_endpoint,
        # is the private ip of the control plane load balancer to be used. This prevents
        # internal k8s traffic from moving across the internet.
        # For kubeconfig, such as a cluster admin (myself) accessing the cluster, we add the
        # load balancer public ip, so that we can actually connect.
        certSANs = [local.controlplane.ip.public]
      }
      controllerManager = {
        extraArgs = {
          # NOTE:
          # The maximum node count in the node subnets would cause ip exhaustion if the
          # default pod count (~110) for k8s was used. Since the cluster pod cidr allocated
          # is not infinite, pod count per node has been reduced.
          node-cidr-mask-size-ipv4 = "26"
        }
      }
    }
  }
}

resource "talos_machine_secrets" "this" {
  talos_version = local.versions.talos
}

data "talos_machine_configuration" "controlplane" {
  cluster_name = "homelab"
  machine_type = "controlplane"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${local.controlplane.ip.private}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = [yamlencode(local.controlplane_config)]
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = hcloud_server.controlplane

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  # public ip needed, otherwise tofu can't reach nodes
  node = each.value.ipv4_address
}

resource "talos_machine_bootstrap" "controlplane" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  node = local.controlplane.bootstrap_node.ipv4_address
  client_configuration = talos_machine_secrets.this.client_configuration
}
locals {
  network_cidr = "10.128.0.0/16"
  # /17 networks
  # 10.128.0.0/17
  reserved_cidr = cidrsubnet(local.network_cidr, 1, 0)
  # 10.128.0.0/28
  # for load balancers, bastion hosts (if ever), etc.
  infra_cidr = cidrsubnet(local.reserved_cidr, 11, 0)
  
  # 10.128.128.0/17
  cluster_cidr = cidrsubnet(local.network_cidr, 1, 1)
  # /24 networks
  node_net = {
    # 10.128.128.0/24
    controlplane_cidr = cidrsubnet(local.cluster_cidr, 7, 0)
    # 10.128.129.0/24
    app_cidr = cidrsubnet(local.cluster_cidr, 7, 1)
    # 10.128.130.0/24
    db_cidr = cidrsubnet(local.cluster_cidr, 7, 2)
  }
  pod_net = {
    # 10.128.131.0/24
    service_cidr = cidrsubnet(local.cluster_cidr, 7, 3)
    # 10.128.224.0/19
    # All pods should be able to reach each other over the network
    pod_cidr = cidrsubnet(local.cluster_cidr, 2, 3)
  }
}

resource "hcloud_network" "homelab_network" {
  name = "homelab_network"
  ip_range = local.network_cidr
}

# Subnets
resource "hcloud_network_subnet" "infrastructure_subnet" {
  network_id = hcloud_network.homelab_network.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = local.infra_cidr
}

resource "hcloud_network_subnet" "controlplane_subnet" {
  network_id = hcloud_network.homelab_network.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = local.node_net.controlplane_cidr
}

resource "hcloud_network_subnet" "application_subnet" {
  network_id = hcloud_network.homelab_network.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = local.node_net.app_cidr
}

resource "hcloud_network_subnet" "database_subnet" {
  network_id = hcloud_network.homelab_network.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = local.node_net.db_cidr
}

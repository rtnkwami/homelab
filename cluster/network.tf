locals {
  _network_cidr_global = "10.128.0.0/16"
  # 10.128.0.0/17
  _network_cidr_reserved = cidrsubnet(local._network_cidr_global, 1, 0)
  # 10.128.128.0/17
  _network_cidr_k8s = cidrsubnet(local._network_cidr_global, 1, 1)

  network_config = {
    cidrs = {
      # 10.128.0.0/28
      infra = cidrsubnet(local._network_cidr_reserved, 11, 0)
      # 10.128.128.0/24
      controlplane = cidrsubnet(local._network_cidr_k8s, 7, 0)
      # 10.128.129.0/24
      app = cidrsubnet(local._network_cidr_k8s, 7, 1)
      # 10.128.130.0/24
      db = cidrsubnet(local._network_cidr_k8s, 7, 2)
      # 10.128.131.0/24
      k8s_services = cidrsubnet(local._network_cidr_k8s, 7, 3)
      # 10.128.224.0/19
      k8s_pods = cidrsubnet(local._network_cidr_k8s, 2, 3)
    }
  }
}
locals {
  # NOTE: Network Configuration
  
  # This divides the Hetzner network into two parts, the first part is reserved for
  # Hetzner infrastructure and other infra unrelated to the k8s cluster
  network_cidrs = {
    # NOTE: First half of hcloud network
    infra = cidrsubnet(var.network_cidr, 11, 0)
    # NOTE: Second half of hcloud network used for k8s cluster
    controlplane = cidrsubnet(var.network_cidr, 8, 128)
    app = cidrsubnet(var.network_cidr, 8, 129)
    db = cidrsubnet(var.network_cidr, 8, 130) 
    k8s_services = cidrsubnet(var.network_cidr, 8, 131)
    # NOTE: Use the last /18 block for pod CIDRs. This allows for ~16k pods in the cluster
    # This caps node growth to about 256 nodes, which is more than enough
    k8s_pods = cidrsubnet(var.network_cidr, 2, 3)
  }
}
locals {
  hcloud_zones = ["nbg1", "fsn1", "hel1"]
  # NOTE: Network Configuration
  
  # This divides the Hetzner network into two parts, the first part is reserved for
  # Hetzner infrastructure and other infra unrelated to the k8s cluster
  network_cidrs = {
    # NOTE: First half of hcloud network
    infra = cidrsubnet(var.network_cidr, 12, 0)
    # NOTE: Second half of hcloud network used for k8s cluster
    controlplane = cidrsubnet(var.network_cidr, 8, 128)
    app = cidrsubnet(var.network_cidr, 8, 129)
    db = cidrsubnet(var.network_cidr, 8, 130) 
    k8s_services = cidrsubnet(var.network_cidr, 8, 131)
    # NOTE: Use the last /18 block for pod CIDRs. This allows for ~16k pods in the cluster
    # This caps node growth to about 256 nodes, which is more than enough
    k8s_pods = cidrsubnet(var.network_cidr, 2, 3)
  }

  # NOTE: Autoscaling configuration
  _nodepool_server_types = [
    "cx23", "cx33", "cx43",
    "cpx22", "cpx32", "ccx13",
    "cpx42", "ccx23"
  ]

  _autoscaler_nodepools = flatten([
    for pool, config in local._nodepools : [
      for type in local._nodepool_server_types : [
        for zone in local.hcloud_zones : {
          name = "${pool}-${type}-${zone}"
          instance_type = type
          location = zone
          subnet = config.subnet
          labels = config.labels
          taints = config.taints
          min = config.min
          max = config.max
        }
      ]
    ]
  ])

  _nodepools = {
    system = {
      min = 0
      max = 5
      subnet = local.network_cidrs.app
      machine_config_overrides = [
        # NOTE: make only system nodes tailscale subnet routers.
        {
          apiVersion = "v1alpha1"
          kind       = "ExtensionServiceConfig"
          name       = "tailscale"
          environment = [
            "TS_AUTHKEY=${var.tailscale_authkey}",
            "TS_ROUTES=${local.network_cidrs.controlplane}",
          ]
        }
      ]
      labels = {
        "node.niovial.io/pool" = "system"
      }
      taints = [{
        key = "node.niovial.io/pool"
        value = "system"
        effect = "NoSchedule"
      }]
    }

    general = {
      min = 0
      max = 20
      subnet = local.network_cidrs.app
      labels = {
        "node.niovial.io/pool" = "general"
      }
      taints = []
    }

    database = {
      min = 0
      max = 20
      subnet = local.network_cidrs.db
      labels = {
        "node.niovial.io/pool" = "database"
      }
      taints = [{
        key = "node.niovial.io/pool"
        value = "database"
        effect = "NoSchedule"
      }]
    }
  }
}
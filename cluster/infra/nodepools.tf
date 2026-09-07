locals {
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

  # NOTE:
  # The schema for each nodepool is:
  # <pool-name> = {
  #   subnet = string (cidr range)
  #   min = number
  #   max = number
  #   labels = map
  #   taints = list
  # }
  # For each nodepool/group here, a cluster autoscaler autoscaling group will be created
  # per server type and zone.
  _nodepools = {
    system = {
      labels = {
        "node.niovial.io/pool" = "system"
      }
      taints = [
        {
          key = "node.niovial.io/pool"
          value = "system"
          effect = "NoSchedule"
        }
      ]
      min = 0
      max = 5
      subnet = local.network_config.cidrs.app
    }
    general = {
      labels = {
        "node.niovial.io/pool" = "general"
      }
      taints = []
      min = 0
      max = 20
      subnet = local.network_config.cidrs.app
    }
  }
}
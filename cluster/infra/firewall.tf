resource "hcloud_firewall" "controlplane" {
  name = "controlplane-firewall"

  rule {
    direction = "in"
    protocol = "tcp"
    port = 6443
    source_ips = [hcloud_load_balancer_network.this.ip]
  }

  rule {
    direction = "in"
    protocol = "tcp"
    port = 50000
    source_ips = [hcloud_load_balancer_network.this.ip]
  }

  apply_to {
    label_selector = "node.niovial.io/pool=controlplane"
  }
}

resource "hcloud_firewall" "workers" {
  name = "app-worker-firewall"

  # Every node should be able to talk to every other node in the cluster. But outsiders can't
  # communicate with cluster nodes via their public ips.
  rule {
    direction = "in"
    protocol = "tcp"
    source_ips = [
      local.network_config.cidrs.infra,
      local.network_config.cidrs.controlplane,
      local.network_config.cidrs.app,
      local.network_config.cidrs.db
    ]
  }

  # NOTE:
  # All nodes created via cluster autoscaler possess this label.
  # Attempting to config serverLabels within cluster autoscaler nodeConfigs will not
  # work, due to serverLabels not propagating to Hcloud itself.
  # As such, the generic label selector must be used.
  apply_to {
    label_selector = "hcloud/node-group"
  }
}
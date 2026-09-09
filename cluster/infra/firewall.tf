resource "hcloud_firewall" "controlplane" {
  name = "homelab-controlplane-firewall"

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
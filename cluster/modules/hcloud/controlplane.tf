# SECTION: Server creation
resource "hcloud_placement_group" "controlplane" {
  name = "${var.cluster_name}-controlplane"
  type = "spread"
}

resource "hcloud_server" "controlplane" {
  for_each = toset(local.hcloud_zones)

  name = "${var.cluster_name}-controlplane-${each.value}"
  server_type = "cx33"
  location = each.value
  image = data.hcloud_image.x86_image.id
  ssh_keys = [hcloud_ssh_key.this.id]
  # prevent control plane nodes from landing on the same physical server
  placement_group_id = hcloud_placement_group.controlplane.id

  public_net {
    ipv4_enabled = true
  }

  labels = {
    "node.niovial.io/pool" = "controlplane"
  }
}

resource "hcloud_server_network" "controlplane" {
  for_each = hcloud_server.controlplane

  server_id = hcloud_server.controlplane[each.key].id
  subnet_id = hcloud_network_subnet.controlplane_subnet.id
}

# SECTION: Expose control plane nodes via load balancer

resource "hcloud_load_balancer" "controlplane" {
  name = "${var.cluster_name}-controlplane-lb"
  load_balancer_type = "lb11"
  network_zone = "eu-central"
}

resource "hcloud_load_balancer_network" "controlplane" {
  load_balancer_id = hcloud_load_balancer.controlplane.id
  subnet_id = hcloud_network_subnet.infrastructure_subnet.id
}

resource "hcloud_load_balancer_service" "k8s-api" {
  load_balancer_id = hcloud_load_balancer.controlplane.id
  protocol = "tcp"
  listen_port = 6443
  destination_port = 6443

  health_check {
    protocol = "tcp"
    port     = 6443
    retries  = 3
    interval = 10
    timeout  = 5
  }
}

resource "hcloud_load_balancer_target" "controlplane" {
  type = "label_selector"
  load_balancer_id = hcloud_load_balancer.controlplane.id
  label_selector = "node.niovial.io/pool=controlplane"
}

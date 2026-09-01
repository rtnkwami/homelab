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
}

resource "hcloud_server_network" "controlplane" {
  for_each = hcloud_server.controlplane

  server_id = hcloud_server.controlplane[each.key].id
  subnet_id = hcloud_network_subnet.controlplane_subnet.id
}

# SECTION: Server configuration. See also talos.tf for cluster config



# -----------
# NOTE: The ssh key in this section is used specifically
# to ensure that during the creation of servers, Hetzner
# does not send me an email.
resource "hcloud_ssh_key" "this" {
  name = "useless-ssh-key-${random_uuid.this.id}"
  public_key = tls_private_key.this.public_key_openssh
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

resource "random_uuid" "this" {}
# -----------

# -----------
# SECTION: Control Plane
locals {
  hcloud_zones = ["nbg1", "fsn1", "hel1"]
}

data "hcloud_image" "talos_x86" {
  with_selector = "os=talos"
  with_architecture = "x86"
}

resource "hcloud_placement_group" "controlplane" {
  name = "controlplane"
  type = "spread"
}

resource "hcloud_server" "controlplane" {
  for_each = toset(local.hcloud_zones)

  name = "controlplane-${each.value}"
  server_type = "cpx22"
  location = each.value
  image = data.hcloud_image.talos_x86.id
  ssh_keys = [hcloud_ssh_key.this.id]
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
  subnet_id = hcloud_network_subnet.controlplane.id
}
# -----------
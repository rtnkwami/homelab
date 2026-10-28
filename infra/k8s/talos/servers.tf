locals {
  talos_snapshot_name = "talos-${local.versions.talos}-tailscale"
}

data "talos_image_factory_extensions_versions" "this" {
  talos_version = local.versions.talos
  filters = {
    names = ["tailscale"]
  }
}

resource "talos_image_factory_schematic" "talos_tailscale" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info.*.name
      }
    }    
  })
}

data "talos_image_factory_urls" "talos_tailscale" {
  talos_version = local.versions.talos
  schematic_id =  talos_image_factory_schematic.talos_tailscale.id
  platform = "hcloud"
}

resource "imager_image" "talos_tailscale" {
  image_url = "${data.talos_image_factory_urls.talos_tailscale.urls.disk_image}"
  architecture = "x86"
  location = "hel1"
  description = "${local.talos_snapshot_name}-x86"
  labels = {
    os = local.talos_snapshot_name
  }
  
  timeouts {
    create = "10m"
  }
}

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
resource "hcloud_placement_group" "controlplane" {
  name = "controlplane"
  type = "spread"
}

resource "hcloud_server" "controlplane" {
  for_each = toset(local.hcloud_zones)

  name = "controlplane-${each.value}"
  server_type = "cx33"
  location = each.value
  image = imager_image.talos_tailscale.image_id
  ssh_keys = [hcloud_ssh_key.this.id]
  placement_group_id = hcloud_placement_group.controlplane.id

  public_net {
    ipv4_enabled = true
  }

  labels = {
    "node.niovial.io/pool" = "controlplane"
  }

  lifecycle {
    ignore_changes = [image]
  }
}

resource "hcloud_server_network" "controlplane" {
  for_each = hcloud_server.controlplane

  server_id = hcloud_server.controlplane[each.key].id
  subnet_id = hcloud_network_subnet.controlplane.id
}
# -----------
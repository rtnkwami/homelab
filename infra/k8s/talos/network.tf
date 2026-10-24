resource "hcloud_network" "this" {
  name = "main"
  ip_range = var.network_cidr
}

resource "hcloud_network_subnet" "infra" {
  network_id = hcloud_network.this.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = local.network_cidrs.infra
}

resource "hcloud_network_subnet" "controlplane" {
  network_id = hcloud_network.this.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = local.network_cidrs.controlplane
}

resource "hcloud_network_subnet" "app" {
  network_id = hcloud_network.this.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = local.network_cidrs.app
}

resource "hcloud_network_subnet" "db" {
  network_id = hcloud_network.this.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = local.network_cidrs.db
}

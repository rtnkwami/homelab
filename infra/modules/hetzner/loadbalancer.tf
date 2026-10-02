resource "hcloud_load_balancer" "this" {
  name = "controlplane"
  load_balancer_type = "lb11"
  network_zone = "eu-central"
}

resource "hcloud_load_balancer_network" "this" {
  load_balancer_id = hcloud_load_balancer.this.id
  subnet_id = hcloud_network_subnet.infra.id
  
  enable_public_interface = var.is_bootstrap
}

resource "hcloud_load_balancer_service" "this" {
  load_balancer_id = hcloud_load_balancer.this.id
  protocol = "tcp"
  listen_port = 6443
  destination_port = 6443

  health_check {
    protocol = "tcp"
    port = 6443
    retries = 3
    interval = 10
    timeout = 5
  }
}

resource "hcloud_load_balancer_service" "talos_api" {
  load_balancer_id = hcloud_load_balancer.this.id
  protocol = "tcp"
  listen_port = 50000
  destination_port = 50000

  health_check {
    protocol = "tcp"
    port = 50000
    retries = 3
    interval = 10
    timeout = 5
  }
}

resource "hcloud_load_balancer_target" "this" {
  depends_on = [hcloud_load_balancer_network.this]

  type = "label_selector"
  load_balancer_id = hcloud_load_balancer.this.id
  label_selector = "node.niovial.io/pool=controlplane"
  use_private_ip = true
}
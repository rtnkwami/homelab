data "talos_machine_configuration" "tailscale_router" {
  cluster_name = "homelab"
  machine_type = "worker"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${local.controlplane.ip.private}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = [
    for document  in [
      {
        apiVersion = "v1alpha1"
        kind       = "ExtensionServiceConfig"
        name       = "tailscale"
        environment = [
          "TS_AUTHKEY=${var.tailscale_authkey}",
          "TS_ROUTES=${local.network_cidrs.controlplane}",
        ]
      },
      {
        apiVersion = "v1alpha1"
        kind =  "CRICustomizationConfig"
        name = "prevent-image-layer-discarding"
        content = <<-EOF
          [plugins."io.containerd.cri.v1.images"]
          discard_unpacked_layers = false
        EOF
      },
      {
        apiVersion = "v1alpha1"
        kind =  "KubeNodeConfig"
        labels = {
          "node.niovial.io/pool" = "system"
        }
      },
      {
        apiVersion = "v1alpha1"
        kind =  "KubeletConfig"
        config = {
          serverTLSBootstrap = true
          registerWithTaints = [{
            key = "node.niovial.io/pool"
            value = "system"
            effect = "NoSchedule"
          }]
        }
        clusterDNS = [cidrhost(local.network_cidrs.k8s_services, 10)]
        extraArgs = {
          cloud-provider = "external"
        }
      }
    ] : yamlencode(document)
  ]
}

resource "hcloud_server" "tailscale_router_0" {
  name = "ts-router-0"
  server_type = "cx23"
  location = "nbg1"
  image = imager_image.talos_tailscale.image_id
  ssh_keys = [hcloud_ssh_key.this.id]
  user_data = data.talos_machine_configuration.tailscale_router.machine_configuration

  labels = {
    "hcloud/node-group" = "system-cx23-nbg1"
  }

  public_net {
    ipv4_enabled = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = all
  }
}

resource "hcloud_server_network" "tailscale_router_0" {
  server_id = hcloud_server.tailscale_router_0.id
  subnet_id = hcloud_network_subnet.app.id
}

resource "hcloud_server" "tailscale_router_1" {
  name = "ts-router-1"
  server_type = "cx23"
  location = "hel1"
  image = imager_image.talos_tailscale.image_id
  ssh_keys = [hcloud_ssh_key.this.id]
  user_data = data.talos_machine_configuration.tailscale_router.machine_configuration
  
  labels = {
    "hcloud/node-group" = "system-cx23-hel1"
  }

  public_net {
    ipv4_enabled = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = all
  }
}

resource "hcloud_server_network" "tailscale_router_1" {
  server_id = hcloud_server.tailscale_router_1.id
  subnet_id = hcloud_network_subnet.app.id
}
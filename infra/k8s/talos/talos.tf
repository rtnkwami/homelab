locals {
  cluster_name = "homelab"
  tailnet_dns = "taildbf360.ts.net"
}

resource "talos_machine_secrets" "this" {}

ephemeral "talos_cluster_kubeconfig" "this" {
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_name = local.cluster_name
  endpoint = "https://${hcloud_load_balancer_network.this.ip}:6443"
}

resource "talos_machine" "controlplane_0" {
  depends_on = [hcloud_server_network.controlplane_2]

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane.machine_configuration
  # NOTE: talos_machine will upgrade control plane talos os if the talos version changes
  image = data.talos_image_factory_urls.talos_tailscale.urls.installer
  # NOTE: set this because talos_cluster handles k8s upgrades, while talos_machine handles talos upgrades
  ignore_kubernetes_upgrade_drift = true
  kubeconfig_wo = ephemeral.talos_cluster_kubeconfig.this.kubeconfig_raw
  
  node = hcloud_server_network.controlplane_0.ip
  endpoint = "controlplane-1.${local.tailnet_dns}"
}

resource "talos_machine" "controlplane_1" {
  depends_on = [talos_machine.controlplane_0]

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane.machine_configuration
  image = data.talos_image_factory_urls.talos_tailscale.urls.installer
  ignore_kubernetes_upgrade_drift = true
  kubeconfig_wo = ephemeral.talos_cluster_kubeconfig.this.kubeconfig_raw
 
  node = hcloud_server_network.controlplane_1.ip
  endpoint = "controlplane-2.${local.tailnet_dns}"
}

resource "talos_machine" "controlplane_2" {
  depends_on = [talos_machine.controlplane_1]

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane.machine_configuration
  image = data.talos_image_factory_urls.talos_tailscale.urls.installer
  ignore_kubernetes_upgrade_drift = true
  kubeconfig_wo = ephemeral.talos_cluster_kubeconfig.this.kubeconfig_raw
  
  node = hcloud_server_network.controlplane_2.ip
  endpoint = "controlplane.${local.tailnet_dns}"
}

resource "talos_cluster" "this" {
  depends_on = [talos_machine.controlplane_2]

  control_plane_nodes = [
    hcloud_server_network.controlplane_0.ip,
    hcloud_server_network.controlplane_1.ip,
    hcloud_server_network.controlplane_2.ip
  ]
  client_configuration = talos_machine_secrets.this.client_configuration
  kubernetes_version = local.versions.k8s

  node = hcloud_server_network.controlplane_0.ip
  endpoint = hcloud_load_balancer_network.this.ip
}

data "talos_cluster_health" "this" {
  depends_on = [talos_cluster.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  # NOTE: I have no idea why, but if I set this to false, this healthcheck hangs forever
  skip_kubernetes_checks = true
  control_plane_nodes = [
    hcloud_server_network.controlplane_0.ip,
    hcloud_server_network.controlplane_1.ip,
    hcloud_server_network.controlplane_2.ip
  ]
  endpoints = [hcloud_load_balancer_network.this.ip]
}

data "talos_client_configuration" "this" {
  cluster_name = local.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes = [
    hcloud_server_network.controlplane_0.ip,
    hcloud_server_network.controlplane_1.ip,
    hcloud_server_network.controlplane_2.ip
  ]
  endpoints = [hcloud_load_balancer_network.this.ip]
}

resource "local_sensitive_file" "talos_config" {
  content = data.talos_client_configuration.this.talos_config
  filename = var.talosconfig_path
  file_permission = "0600"
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_cluster.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node = hcloud_server_network.controlplane_0.ip
  endpoint = hcloud_load_balancer_network.this.ip
}

resource "local_sensitive_file" "kubeconfig" {
  content = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = var.kubeconfig_path
  file_permission = "0600"
}

# NOTE: This resource causes "talosctl upgrade-k8s" to be run against the cluster when
# talos inline manifests are changed. If this command is not run against the cluster,
# talos will never update the live manifests, regardless of how many applies you do.
# In addition, although talos_cluster.this runs "talosctl upgrade-k8s", it only does so
# when the k8s version changes. This means that regular configuration of inline manifests
# will never reconcile unless you are doing an actual upgrade of k8s.
# As such this script is needed to run it manually.
resource "terraform_data" "reconcile_inline_manifests" {
  depends_on = [local_sensitive_file.talos_config]
  triggers_replace = [sha256(jsonencode(local.talos_inline_manifests))]

  provisioner "local-exec" {
    environment = {
      TALOSCONFIG = var.talosconfig_path
    }
    command = "talosctl upgrade-k8s -n ${hcloud_load_balancer_network.this.ip} --to ${local.versions.k8s}"
  }
}

# NOTE:
resource "terraform_data" "drain_outdated_k8s_nodes" {
  depends_on = [talos_cluster_kubeconfig.this]
  triggers_replace = [local.versions.k8s]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
      KUBE_VERSION = local.versions.k8s
    }
    command = "go run ./.bin/drain_nodes.go"
  }
}

resource "terraform_data" "drain_outdated_talos_nodes" {
  depends_on = [talos_cluster_kubeconfig.this]
  triggers_replace = [local.versions.talos]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
      TALOS_VERSION = local.versions.talos
    }
    command = "go run ./.bin/drain_nodes.go"
  }
}
data "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node = local.controlplane.bootstrap_node.ipv4_address
}

locals {
  kubeconfig_patch = replace(
    data.talos_cluster_kubeconfig.this.kubeconfig_raw,
    "server: https://${local.controlplane.ip.private}:6443",
    "server: https://${local.controlplane.ip.public}:6443"
  )
}

resource "local_sensitive_file" "kubeconfig" {
  content = local.kubeconfig_patch
  filename = "out/kubeconfig"
  file_permission = "0600"
}

data "talos_client_configuration" "this" {
  cluster_name = "homelab"
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes = [for node in hcloud_server.controlplane : node.ipv4_address]
  endpoints = [local.controlplane.ip.public]
}

resource "local_sensitive_file" "talos_config" {
  content = data.talos_client_configuration.this.talos_config
  filename = "out/talosconfig"
  file_permission = "0600"
}
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.controlplane[local.hcloud_zones[0]].ipv4_address
  depends_on           = [talos_machine_bootstrap.this]
}

resource "local_sensitive_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "kubeconfig"
  file_permission = "0600"
}

data "talos_client_configuration" "this" {
  cluster_name          = var.cluster_name
  client_configuration  = talos_machine_secrets.this.client_configuration
  nodes                 = [for z in local.hcloud_zones : hcloud_server.controlplane[z].ipv4_address]
  endpoints             = [for z in local.hcloud_zones : hcloud_server.controlplane[z].ipv4_address]
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "talosconfig"
  file_permission = "0600"
}
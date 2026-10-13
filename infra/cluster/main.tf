module "hetzner" {
  source = "../modules/hetzner"

  hcloud_token = var.hcloud_token
  tailscale_authkey = var.tailscale_node_key
  is_bootstrap = true

  kubeconfig_path = "${path.root}/out/kubeconfig"
  talosconfig_path = "${path.root}/out/kubeconfig"
}

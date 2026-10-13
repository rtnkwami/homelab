variable "hcloud_token" {
  sensitive = true
}

variable "tailscale_authkey" {
  sensitive = true
}

variable "is_bootstrap" {
  type = bool
  default = false
}

variable "kubeconfig_path" {
  type = string
  default = "out/kubeconfig"
}

variable "talosconfig_path" {
  type = string
  default = "out/talosconfig"
}
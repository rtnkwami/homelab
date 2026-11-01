variable "network_cidr" {
  type = string
  default = "10.128.0.0/16"
}

variable "hcloud_token" {
  sensitive = true
}

variable "tailscale_authkey" {
  sensitive = true
}

variable "kubeconfig_path" {
  type = string
  default = ".config/kubeconfig"
}

variable "talosconfig_path" {
  type = string
  default = ".config/talosconfig"
}
variable "hcloud_token" {
  sensitive = true
}

variable "tailscale_node_key" {
  sensitive = true
}

variable "cloud_provider" {
  type = string
  default = "hetzner"
  description = "The cloud provider to use to deploy the homelab cluster"
  
  validation {
    condition = contains(["aws", "hetzner"], var.cloud_provider)
    error_message = "The cloud_provider value must be either \"aws\" or \"hetzner\" "
  }
}
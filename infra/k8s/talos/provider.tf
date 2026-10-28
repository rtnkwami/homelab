provider "hcloud" {
  token = var.hcloud_token
}

provider "imager" {
  token = var.hcloud_token
}

provider "aws" {
  region = "us-east-1"
}

provider "helm" {
  alias = "deploy"
  kubernetes = {
    host = "https://${local.controlplane.ip.private}:6443"
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
    client_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  }
}
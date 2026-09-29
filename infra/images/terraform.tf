terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws",
      version = "~>6.0"
    }
    talos = {
      source = "siderolabs/talos"
      version = "0.11.0"
    }
    imager = {
      source = "hcloud-talos/imager"
      version = "~>1.0"
    }
  }
}
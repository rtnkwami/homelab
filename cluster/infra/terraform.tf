terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>6.0"
    }

    hcloud = {
      source = "hetznercloud/hcloud"
      version = "~>1.0"
    }

    talos = {
      source = "siderolabs/talos"
      version = "0.11.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }

    random = {
      source = "hashicorp/random"
      version = "~>3.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~>2.0"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~>3.0"
    }
  }
}
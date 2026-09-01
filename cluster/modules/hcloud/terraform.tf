terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "~>1.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }

    random = {
      source = "hashicorp/random"
      version = "~>3.0"
    }
  }
}
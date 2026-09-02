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
  }
}
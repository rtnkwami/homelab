provider "hcloud" {
  token = var.hcloud_token
}

provider "imager" {
  token = var.hcloud_token
}

provider "aws" {
  region = "us-east-1"
}
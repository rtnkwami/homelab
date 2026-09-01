data "hcloud_image" "x86_image" {
  with_selector = "os=talos"
  with_architecture = "x86"
}

locals {
  hcloud_zones = ["nbg1", "fsn1", "hel1"]
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

resource "random_uuid" "this" {}

# If this is not used to create servers, hcloud will send an email for every cluster created
# it's a very good (or bad) way to hit your email with spam
resource "hcloud_ssh_key" "this" {
  name = "${var.cluster_name}-ssh-${random_uuid.this.id}"
  public_key = tls_private_key.this.public_key_openssh
}
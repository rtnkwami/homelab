module "hcloud" {
  source = "./modules/hcloud"

  access_token = var.hcloud_token
}
terraform {
  backend "s3" {
    bucket = "niovial-homelab"
    key = "tofu-talos-snapshot-state"
    encrypt = true
    use_lockfile = true
  }
}
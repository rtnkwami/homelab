terraform {
  backend "s3" {
    bucket = "niovial-homelab"
    key = "homelab"
    encrypt = true
    use_lockfile = true
  }
}
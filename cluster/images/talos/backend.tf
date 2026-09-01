terraform {
  backend "s3" {
    bucket = "niovial-homelab"
    key = "os/talos"
    encrypt = true
    use_lockfile = true
  }
}
terraform {
  backend "s3" {
    bucket = "niovial-homelab"
    key = "k8s-state"
    encrypt = true
    use_lockfile = true
  }
}
terraform {
  backend "s3" {
    bucket = "niovial-homelab"
    key = "k8s/talos"
    encrypt = true
    use_lockfile = true
  }
}
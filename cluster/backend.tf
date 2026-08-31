terraform {
  backend "s3" {
    bucket = "niovial-homelab"
    key = "k8s"
    encrypt = true
    use_lockfile = true
  }
}
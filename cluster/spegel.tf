locals {
  _spegel_namespace_manifest = {
    apiVersion = "v1"
    kind = "Namespace"
    metadata = {
      name = "spegel"
      labels = {
        "pod-security.kubernetes.io/enforce" = "privileged"
      }
    }
  }
}

data "helm_template" "spegel" {
  name = "spegel"
  chart = "spegel"
  repository = "oci://ghcr.io/spegel-org/helm-charts"
  namespace = "spegel"
  version = local.versions.spegel
  kube_version = local.versions.k8s

  values = [
    yamlencode({
      spegel = {
        containerdRegistryConfigPath = "/etc/cri/conf.d/hosts"
      }
    })
  ]
}

locals {
  spegel_manifest = {
    name = "spegel"
    contents = <<-EOF
      ${data.helm_template.spegel.manifest}
      ---
      ${yamlencode(local._spegel_namespace_manifest)}
    EOF
    
  }
}


resource "helm_release" "spegel" {
  provider = helm.deploy
  
  name = "spegel"
  chart = "spegel"
  repository = "oci://ghcr.io/spegel-org/helm-charts"
  namespace = "spegel"
  create_namespace = true
  version = local.versions.spegel

  values = [
    yamlencode({
      spegel = {
        containerdRegistryConfigPath = "/etc/cri/conf.d/hosts"
      }
    })
  ]
}

locals {
  spegel_namespace_manifest = {
    apiVersion = "v1alpha1"
    kind =  "KubeInlineManifestConfig"
    name = "spegel"
    manifest = yamlencode({
      apiVersion = "v1"
      kind = "Namespace"
      metadata = {
        name = "spegel"
        labels = {
          "pod-security.kubernetes.io/enforce" = "privileged"
        }
      }
    })
  }
}
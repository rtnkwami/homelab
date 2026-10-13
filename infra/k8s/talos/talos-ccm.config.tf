data "helm_template" "talos_ccm" {
  name = "talos-cloud-controller-manager"
  chart = "talos-cloud-controller-manager"
  repository = "oci://ghcr.io/siderolabs/charts"
  namespace = "kube-system"
  version = local.versions.talos_ccm
  kube_version = local.versions.k8s

  values = [yamlencode({
    daemonSet = {
      enabled = true
      k8s = {
        # See cni.config.tf under k8sServiceHost
        serviceHost = "127.0.0.1"
        servicePort = 7445
      }
    }
  })]
}

locals {
  talos_ccm_manifest = {
    name = "talos-ccm"
    contents = data.helm_template.talos_ccm.manifest
  }
}
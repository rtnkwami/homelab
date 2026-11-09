resource "helm_release" "flux_operator" {
  provider = helm.deploy
  
  name = "flux-operator"
  chart = "flux-operator"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts/"
  namespace = "flux-system"
  create_namespace = true

  values = [
    yamlencode({
      nodeSelector = {
        "node-role.kubernetes.io/control-plane" = ""
      }
      tolerations = [{
        key = "node-role.kubernetes.io/control-plane"
        operator = "Exists"
      }]
    })
  ]

  lifecycle {
    ignore_changes = all
  }
}
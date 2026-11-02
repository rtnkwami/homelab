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
        "node.niovial.io/pool" = "system"
      }
      tolerations = [{
        key = "node.niovial.io/pool"
        operator = "Equal"
        value = "system"
      }]
    })
  ]

  lifecycle {
    ignore_changes = all
  }
}
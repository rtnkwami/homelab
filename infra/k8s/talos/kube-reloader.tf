resource "helm_release" "kube_reloader" {
  provider = helm.deploy
  
  name = "kube-reloader"
  chart = "reloader"
  repository = "https://stakater.github.io/stakater-charts"
  namespace = "kube-reloader"
  create_namespace = true

  values = [
    yamlencode({
      reloader = {
        enableHA = true
        deployment = {
          replicas = 2
          nodeSelector = {
            "node.niovial.io/pool" = "system"
          }
          tolerations = [{
            key = "node.niovial.io/pool"
            operator = "Equal"
            value = "system"
          }]
          topologySpreadConstraints = [{
            topologyKey       = "topology.kubernetes.io/zone"
            maxSkew           = 1
            minDomains = 2
            whenUnsatisfiable = "DoNotSchedule"
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/instance" = "kube-reloader"
              }
            }
            matchLabelKeys = ["pod-template-hash"]
          }]
        }
      }
    })
  ]
  
  lifecycle {
    ignore_changes = all
  }
}
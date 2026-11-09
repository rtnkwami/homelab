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
            "node-role.kubernetes.io/control-plane" = ""
          }
          tolerations = [{
            key = "node-role.kubernetes.io/control-plane"
            operator = "Exists"
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
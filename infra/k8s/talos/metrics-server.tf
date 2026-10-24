data "helm_template" "kube_metrics_server" {
  name = "kube-metrics-server"
  chart = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  namespace = "kube-system"
  version = local.versions.metrics_server
  kube_version = local.versions.k8s

  values = [
    yamlencode({
      nodeSelector = {
        "node-role.kubernetes.io/control-plane" = ""
      }
      tolerations = [{
        key = "node-role.kubernetes.io/control-plane"
        operator = "Exists"
      }]
      replicas = 3
      podDisruptionBudget = {
        enabled = true
        minAvailable = 1
      }
      topologySpreadConstraints = [{
        topologyKey       = "topology.kubernetes.io/zone"
          maxSkew           = 1
          minDomains        = 3
          whenUnsatisfiable = "DoNotSchedule"
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/instance"  = "kube-metrics-server"
            }
          }
          matchLabelKeys = ["pod-template-hash"]
      }]
    })
  ]
}

locals {
  kube_metrics_server_manifest = {
    apiVersion = "v1alpha1"
    kind =  "KubeInlineManifestConfig"
    name = "kube-metrics-server"
    manifest = data.helm_template.kube_metrics_server.manifest
  }
}
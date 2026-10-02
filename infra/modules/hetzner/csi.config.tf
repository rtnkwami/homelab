locals {
  _csi_config = {
    controller = {
      nodeSelector = {
        "node-role.kubernetes.io/control-plane" = ""
      }
      tolerations = [
        {
          key = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
        }
      ]
      replicaCount = 3
      topologySpreadConstraints = [
        {
          topologyKey       = "topology.kubernetes.io/zone"
          maxSkew           = 1
          # if other control plane nodes are not ready, wait until ready
          # before attempting to schedule pods
          minDomains        = 3
          whenUnsatisfiable = "DoNotSchedule"
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/name"      = "hcloud-csi"
              "app.kubernetes.io/instance"  = "hcloud-csi"
              "app.kubernetes.io/component" = "controller"
            }
          }
          matchLabelKeys = ["pod-template-hash"]
        }
      ]
    }
  }
}

data "helm_template" "hcloud_csi" {
  name = "hcloud-csi"
  chart = "hcloud-csi"
  repository = "https://charts.hetzner.cloud"
  namespace = "kube-system"
  version = local.versions.hcloud_csi
  kube_version = local.versions.k8s

  # helm chart also installs a default storage class  
  values = [yamlencode(local._csi_config)]
}

locals {
  csi_manifest = {
    name     = "hcloud-csi"
    contents = data.helm_template.hcloud_csi.manifest
  }
}
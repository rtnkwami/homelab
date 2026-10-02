locals {
  _autoscaler_zones = {
    # https://docs.hetzner.com/cloud/general/locations/
    fsn1 = "fsn1-dc14"
    nbg1 = "nbg1-dc3"
    hel1 = "hel1-dc2"
  }
  _autoscaler_config = {
    cloudProvider = "hetzner"
    # ----------
    # NOTE: Scheduling config
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
        minDomains = 3
        whenUnsatisfiable = "DoNotSchedule"
        labelSelector = {
          matchLabels = {
            "app.kubernetes.io/instance" = "cluster-autoscaler"
          }
        }
        matchLabelKeys = ["pod-template-hash"]
      }
    ]
    # ----------
    # NOTE: Autoscaling config
    # REF: https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-the-parameters-to-ca
    extraArgs = {
      # priority is used here because cheaper nodes are preferred to expensive
      # nodes where available.
      expander = "priority"
      # increase reactivity of cluster autoscaler
      scale-down-unneeded-time = "3m"
      scale-down-delay-after-add = "1m"
      scale-down-delay-after-failure = "1m"
      scale-down-delay-type-local = "true"
    }
    # Configre node groups based on cost and capacity.
    # Prefer cheaper nodes where possible
    expanderPriorities = {
      "100" = [".*-cx23-.*"]
      "90"  = [".*-cx33-.*"]
      "80"  = [".*-cx43-.*", ".*-cpx22-.*"]
      "70"  = [".*-cpx32-.*", ".*-ccx13-.*"]
      "60"  = [".*-cpx42-.*", ".*-ccx23-.*"]
    }
    autoscalingGroups = [
      for pool in local._autoscaler_nodepools : {
        name = pool.name
        instanceType = pool.instance_type
        region = pool.location
        minSize = pool.min
        maxSize = pool.max
      }
    ]
    # ----------
    extraEnvSecrets = {
      HCLOUD_TOKEN = {
        name = "hcloud"
        key  = "token"
      }
    }
    extraVolumeSecrets = {
      # see asg config below
      asg-config = {
        name      = "asg-config"
        mountPath = "/asg"
      }
    }
    extraEnv = {
      HCLOUD_SSH_KEY = tostring(hcloud_ssh_key.this.id)
      HCLOUD_NETWORK = tostring(hcloud_network.this.id)
      HCLOUD_CLUSTER_CONFIG_FILE = "/asg/config"
    }
  }
}

locals {
  _asg_config_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"
    metadata = {
      name      = "asg-config"
      namespace = "kube-system"
    }
    data = {
      config = base64encode(
        jsonencode({
          imagesForArch = {
            # needs to be a string
            amd64 = tostring(data.hcloud_image.talos_x86.id)
          }
          nodeConfigs = {
            for pool in local._autoscaler_nodepools : pool.name => {
              cloudInit = data.talos_machine_configuration.worker[pool.name].machine_configuration
              subnetIPRange = pool.subnet
              labels = merge(
                # NOTE:
                # Although this label is added by default via the k8s control plane, cluster autoscaler
                # sees only the current labels of a node template and not the potential labels. As such,
                # this is needed to prevent issues where workloads with this default node selector
                # fail to schedule.
                {
                  "kubernetes.io/os" = "linux",
                  "topology.kubernetes.io/zone" = local._autoscaler_zones[pool.location]
                },
                pool.labels
              )
              taints = pool.taints
            }
          }
        })
      )
    }
  }
}

data "helm_template" "cluster_autoscaler" {
  name         = "cluster-autoscaler"
  chart        = "cluster-autoscaler"
  repository   = "https://kubernetes.github.io/autoscaler"
  namespace    = "kube-system"
  version      = local.versions.cluster_autoscaler
  kube_version = local.versions.k8s

  values = [yamlencode(local._autoscaler_config)]
}

locals {
  autoscaler_manifest = {
    name     = "cluster-autoscaler"
    contents = <<-EOF
      ${data.helm_template.cluster_autoscaler.manifest}
      ---
      ${yamlencode(local._asg_config_secret)}
    EOF
  }
}
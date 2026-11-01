locals {
  _autoscaler_zones = {
    # https://docs.hetzner.com/cloud/general/locations/
    fsn1 = "fsn1-dc14"
    nbg1 = "nbg1-dc3"
    hel1 = "hel1-dc2"
  }
}

data "helm_template" "cluster_autoscaler" {
  name         = "cluster-autoscaler"
  chart        = "cluster-autoscaler"
  repository   = "https://kubernetes.github.io/autoscaler"
  namespace    = "kube-system"
  version      = local.versions.cluster_autoscaler
  kube_version = local.versions.k8s

  values = [
    yamlencode({
      cloudProvider = "hetzner"
      nodeSelector = {
        "node-role.kubernetes.io/control-plane" = ""
      }
      tolerations = [{
        key = "node-role.kubernetes.io/control-plane"
        operator = "Exists"
      }]
      replicaCount = 3
      deployment = {
        annotations = {
          "secret.reloader.stakater.com/reload" = "asg-config"
        }
      }
      topologySpreadConstraints = [{
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
      }]
      # REF: https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-the-parameters-to-ca
      extraArgs = {
        # priority is used here because cheaper nodes are preferred to expensive
        # nodes where available.
        expander = "priority,least-nodes"
        # increase reactivity of cluster autoscaler
        scale-down-unneeded-time = "1m"
        scale-down-delay-after-add = "1m"
        scale-down-delay-after-failure = "1m"
        scale-down-delay-type-local = "true"
        unremovable-node-recheck-timeout = "30s"
        ignore-daemonsets-utilization = "true"
        max-drain-parallelism = 10
      }
      # Configure node groups based on cost and capacity.
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
          # NOTE: if the node group matches the one that the tailscale routers belong to
          # ensure that cluster autoscaler does not destroy them, to allow for a min of 2
          # system nodes in the cluster at all times.
          minSize = contains(
            [local.ts_router_0_name, local.ts_router_1_name],
            pool.name
          ) ? 1 : 0
          maxSize = pool.max
        }
      ]
      # see hcloud-ccm.tf for hcloud secret manifest
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
    })
  ]
}

locals {
  cluster_autoscaler_manifest = {
    apiVersion = "v1alpha1"
    kind =  "KubeInlineManifestConfig"
    name     = "cluster-autoscaler"
    manifest = data.helm_template.cluster_autoscaler.manifest
  }

  asg_config_manifest = {
    apiVersion = "v1alpha1"
    kind =  "KubeInlineManifestConfig"
    name     = "cluster-autoscaler-config"
    manifest = yamlencode({
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
              amd64 = tostring(imager_image.talos_tailscale.image_id)
            }
            nodeConfigs = {
              for pool in local._autoscaler_nodepools : pool.name => {
                cloudInit = data.talos_machine_configuration.worker[pool.name].machine_configuration
                subnetIPRange = pool.subnet
                labels = merge(
                  # NOTE: Although this label is added by default via the k8s control plane, cluster autoscaler
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
    })
  }
}
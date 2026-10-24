data "helm_template" "cilium" {
  name = "cilium"
  chart = "cilium"
  repository = "oci://quay.io/cilium/charts"
  namespace = "kube-system"
  version = local.versions.cilium
  kube_version = local.versions.k8s

  values = [
    yamlencode({
      # REF: https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium#method-2-helm
      ipam = {
        mode = "kubernetes"
      }
      kubeProxyReplacement = true
      securityContext = {
        capabilities = {
          ciliumAgent = [
            "CHOWN", "KILL", "NET_ADMIN",
            "NET_RAW", "IPC_LOCK", "SYS_ADMIN",
            "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER",
            "SETGID", "SETUID"
          ]
          cleanCiliumState = [
            "NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"
          ]
        }
      }
      cgroup = {
        autoMount = {
          enabled = false
        }
        hostRoot = "/sys/fs/cgroup"
      }
      # NOTE: Unlike what's present in the cilium config on
      # Talos website, localhost cannot be used here in this cluster
      # Using localhost will cause cilium to resolve both ipv6 and ipv4
      # Because ipv6 isn't enabled on this cluster, cilium will error,
      # and refuse to start.
      k8sServiceHost = "127.0.0.1"
      # NOTE: Cilium uses host networking. For all pods that use host networking and need to communicate
      # with the control plane, it is recommended to use KubePrism. KubePrism listens on port 7445
      # on each node.
      # REF: https://docs.siderolabs.com/kubernetes-guides/advanced-guides/kubeprism#:~:text=port
      k8sServicePort = 7445
      k8s = {
        requireIPv4PodCIDR = true
      }
      routingMode = "native"
      ipv4NativeRoutingCIDR = local.network_cidrs.k8s_pods
      cni = {
        exclusive = false
      }
      socketLB = {
        enabled = true
        hostNamespaceOnly = true
      }
      envoy = {
        enabled = false
      }
      operator = {
        nodeSelector = {
          "node-role.kubernetes.io/control-plane" = ""
        }
        replicas = 3
        podDisruptionBudget = {
          enabled = true
        }
      }
    })
  ]
}

locals {
  cilium_manifest = {
    apiVersion = "v1alpha1"
    kind =  "KubeInlineManifestConfig"
    name = "cilium"
    manifest = data.helm_template.cilium.manifest
  }
}
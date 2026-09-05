locals {
  _cni_config = {
    # NOTE: Talos required cilium config
    # ----------
    # REF: https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium#method-2-helm
    ipam = {
      # immutable. If you want to change, recreate cluster
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
    # NOTE:
    # Unlike what's present in the cilium config on
    # Talos website, localhost cannot be used here in this cluster
    # Using localhost will cause cilium to lookup both ipv6 and ipv4
    # Because ipv6 isn't enabled on this cluster, cilium will error,
    # and refuse to start.
    k8sServiceHost = "127.0.0.1"
    # NOTE:
    # Cilium uses host networking, as such, using kube-prism for kube-api
    # access is more reliable than using the control plane load balancer
    # REF: https://docs.siderolabs.com/kubernetes-guides/advanced-guides/kubeprism#:~:text=port
    k8sServicePort = 7445
    # ----------
    k8s = {
      # wait for ipv4 cidr range to nodes before running cilium
      requireIPv4PodCIDR = true
    }
    # NOTE: Performance Optimization
    # ----------
    # NOTE: see ccm.config.tf under networking field in hcloud ccm values
    routingMode = "native"
    # NOTE:
    # Any traffic going to pods within this cluster should not be SNAT'd, because pod IPs
    # are already routable over the hcloud network.
    # REF: network.tf
    ipv4NativeRoutingCIDR = local.network_config.cidrs.k8s_pods
    # Enable eBPF masquerading (instead of default iptables masquerading) on pod IP-> external IP
    # traffic
    bpf = {
      masquerade = true
    }
    # REF: https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/#xdp-acceleration
    loadBalancer = {
      acceleration = "native"
    }
    # ----------
    encryption = {
      enabled = true
      type = "wireguard"
    }
    gatewayAPI = {
      enabled = true
      # NOTE:
      # This is a cluster-wide config, and individual gateways cannot opt out of this. They must
      # all use proxy protocol.
      enableProxyProtocol = true
      gatewayClass = {
        create = true
      }
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
  }
}

data "helm_template" "cilium" {
  name = "cilium"
  chart = "cilium"
  repository = "oci://quay.io/cilium/charts"
  namespace = "kube-system"
  version = local.versions.cilium
  kube_version = local.versions.k8s

  values = [yamlencode(local._cni_config)]
}

locals {
  cni_manifest = {
    name = "cilium"
    contents = data.helm_template.cilium.manifest
  }
}
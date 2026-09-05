locals {
  hcloud_secret_manifest = {
    name = "hcloud-secret"
    contents = yamlencode({
      apiVersion = "v1"
      kind       = "Secret"
      type       = "Opaque"
      metadata = {
        name      = "hcloud"
        namespace = "kube-system"
      }
      data = {
        network = base64encode(hcloud_network.this.id)
        token   = base64encode(var.hcloud_token)
      }
    })
  }
  _ccm_config = {
    # REF: https://github.com/hetznercloud/hcloud-cloud-controller-manager/blob/main/chart/values.yaml
    kind = "DaemonSet"
    # prevents daemonset pods from running on nodes other than control plane
    nodeSelector = {
      "node-role.kubernetes.io/control-plane" = ""
    }
    networking = {
      enabled = true
      clusterCIDR = local.network_config.cidrs.k8s_pods
    }
    env = {
      HCLOUD_LOAD_BALANCERS_ENABLED = { value = "true" }
      HCLOUD_LOAD_BALANCERS_NETWORK_ZONE = { value = "eu-central" }
      # keep k8s traffic on the private network
      HCLOUD_LOAD_BALANCERS_USE_PRIVATE_IP = { value = "true" }
      HCLOUD_LOAD_BALANCERS_PRIVATE_SUBNET_IP_RANGE = { value = hcloud_network_subnet.infra.ip_range }
      # it is possible that ipv6 config can conflict with the proxy protocol setting
      HCLOUD_LOAD_BALANCERS_DISABLE_IPV6            = { value = "true" }
      # do not allow traffic that should be external to be routable via the private network of the load balancer
      HCLOUD_LOAD_BALANCERS_DISABLE_PRIVATE_INGRESS = { value = "true" }
      # the proxy protocol allows cilium to keep track of the src ip of a packet despite it being
      # forwarded by a gateway (to prevent it's src from being replaced by the load balancer)
      # NOTE:
      # Enabling this means that cilium config must also support proxy protocol
      HCLOUD_LOAD_BALANCERS_USES_PROXYPROTOCOL      = { value = "true" }
      # NOTE:
      # Hcloud ccm uses host networking. As such, instead of using the control plane lb,
      # it instead uses kube-prism for reliability.
      # In addition, since ipv6 isn't enabled, localhost is not used, to prevent it from resolving 
      KUBERNETES_SERVICE_HOST = { value = "127.0.0.1" }
      KUBERNETES_SERVICE_PORT = { value = tostring(7445) }
    }
  }
}

data "helm_template" "hcloud_ccm" {
  name = "hcloud-cloud-controller-manager"
  chart = "hcloud-cloud-controller-manager"
  repository   = "https://charts.hetzner.cloud"
  namespace = "kube-system"
  version = local.versions.hcloud_ccm
  kube_version = local.versions.k8s

  values = [yamlencode(local._ccm_config)]
}

locals {
  ccm_manifest = {
    name = "hcloud-ccm"
    contents = data.helm_template.hcloud_ccm.manifest
  }
}

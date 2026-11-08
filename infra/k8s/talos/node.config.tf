data "talos_machine_configuration" "bootstrap" {
  cluster_name = local.cluster_name
  machine_type = "controlplane"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${hcloud_load_balancer_network.this.ip}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = [
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "tailscale"
      environment = [
        "TS_AUTHKEY=${var.tailscale_authkey}",
        "TS_HOSTNAME=controlplane",
        "TS_ROUTES=${local.network_cidrs.infra}",
      ]
    }),
    yamlencode({
      machine = {
        certSANs = [
          hcloud_load_balancer_network.this.ip,
          "controlplane.${local.tailnet_dns}",
          "controlplane-1.${local.tailnet_dns}",
          "controlplane-2.${local.tailnet_dns}"
        ]
      }
    })
  ]
}

locals {
  talos_inline_manifests = [
    local.hcloud_secret_manifest,
    local.talos_ccm_manifest,
    local.hcloud_ccm_manifest,
    local.hcloud_csi_manifest,
    local.cilium_manifest,
    local.kube_metrics_server_manifest,
    local.cluster_autoscaler_manifest,
    local.asg_config_manifest,
    local.spegel_manifest
  ]

  controlplane_configuration = [
    {
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "tailscale"
      environment = [
        "TS_AUTHKEY=${var.tailscale_authkey}",
        "TS_HOSTNAME=controlplane",
        "TS_ROUTES=${local.network_cidrs.infra}",
      ]
    },
    {
      # Spegel requires this configuration to work properly
      apiVersion = "v1alpha1"
      kind =  "CRICustomizationConfig"
      name = "prevent-image-layer-discarding"
      content = <<-EOF
        [plugins."io.containerd.cri.v1.images"]
        discard_unpacked_layers = false
      EOF
    },
    {
      apiVersion = "v1alpha1"
      kind =  "KubeNetworkConfig"
      podSubnets = [local.network_cidrs.k8s_pods]
      serviceSubnets = [local.network_cidrs.k8s_services]
      # NOTE:
      # The maximum node count in the node subnets would cause ip exhaustion if the
      # default pod count (~110) for k8s was used. Since the cluster pod cidr allocated
      # is not infinite, pod count per node has been reduced.
      nodeCIDRMaskSizeIPv4 = 26
    },
    {
      apiVersion = "v1alpha1"
      kind =  "KubeFlannelCNIConfig"
      "$patch" = "delete"
    },
    {
      apiVersion = "v1alpha1"
      kind =  "KubeProxyConfig"
      enabled = false
    },
    {
      apiVersion = "v1alpha1"
      kind =  "KubeNodeConfig"
      nodeIP = {
        validSubnets = [local.network_cidrs.controlplane]
      }
    },
    {
      apiVersion = "v1alpha1"
      kind =  "KubeletConfig"
      config = {
        # NOTE: this setting replaces --rotate-server-certificates
        # It requires RotateKubeletServerCertificate to be set to true (which is its default)
        # REF: https://github.com/kubernetes/enhancements/pull/4411#:~:text=When%20the%20feature%20gate%20%60RotateKubeletServerCertificate%60%20is%20true%2C%20then%20%60ServerTLSBootstrap%60%20is%20also%20required%20to%20be%20true%2E,-To
        serverTLSBootstrap = true
      }
      clusterDNS = [cidrhost(local.network_cidrs.k8s_services, 10)]
      extraArgs = {
        cloud-provider = "external"
      }
    },
    {
      apiVersion = "v1alpha1"
      kind =  "KubeControllerManagerConfig"
      extraArgs = {
        cloud-provider = "external"
      }
    },
    {
      apiVersion = "v1alpha1"
      kind =  "KubeServiceAccountConfig"
      issuer = {
        issuerURL = "https://${local._irsa_oidc_issuer}"
        privateKey = tls_private_key.service_account_signing_key.private_key_pem
      }
      accepted = {
        audiences = [local._irsa_oidc_audience]
      }
    },
    {
      apiVersion = "v1alpha1"
      kind =  "KubeTalosAPIAccessConfig"
      allowedRoles = ["os:reader"]
      allowedKubernetesNamespaces = ["kube-system"]
    },
    {
      machine = {
        certSANs = [
          hcloud_load_balancer_network.this.ip,
          "controlplane.${local.tailnet_dns}",
          "controlplane-1.${local.tailnet_dns}",
          "controlplane-2.${local.tailnet_dns}"
        ]
      }
      cluster = {
        externalCloudProvider = {
          enabled = true
        }
        etcd = {
          advertisedSubnets = [local.network_cidrs.controlplane]
        }
      }
    }
  ]
}

data "talos_machine_configuration" "controlplane" {
  cluster_name = local.cluster_name
  machine_type = "controlplane"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${hcloud_load_balancer_network.this.ip}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = concat(
    [for document in local.controlplane_configuration : yamlencode(document)],
    [for manifest in local.talos_inline_manifests : yamlencode(manifest)]
  )
}

locals {
  worker_configuration = {
    for pool in local._autoscaler_nodepools : pool.name => [
      {
        apiVersion = "v1alpha1"
        kind =  "CRICustomizationConfig"
        name = "prevent-image-layer-discarding"
        content = <<-EOF
          [plugins."io.containerd.cri.v1.images"]
          discard_unpacked_layers = false
        EOF
      },
      {
        apiVersion = "v1alpha1"
        kind =  "KubeletConfig"
        config = {
          # NOTE: this setting replaces --rotate-server-certificates
          # It requires RotateKubeletServerCertificate to be set to true (which is its default)
          # REF: https://github.com/kubernetes/enhancements/pull/4411#:~:text=When%20the%20feature%20gate%20%60RotateKubeletServerCertificate%60%20is%20true%2C%20then%20%60ServerTLSBootstrap%60%20is%20also%20required%20to%20be%20true%2E,-To
          serverTLSBootstrap = true
          registerWithTaints = pool.taints
        }
        # NOTE:
        # if this isn't set on worker nodes, kubelet on worker nodes will
        # try to reach kube-dns on the hardcoded original config which would
        # cause them to timeout with an old ip.
        clusterDNS = [cidrhost(local.network_cidrs.k8s_services, 10)]
        extraArgs = {
          cloud-provider = "external"
        }
      },
      {
        apiVersion = "v1alpha1"
        kind =  "KubeNodeConfig"
        labels = pool.labels
      }
    ]
  }
}

data "talos_machine_configuration" "worker" {
  for_each = { for pool in local._autoscaler_nodepools : pool.name => pool }
  
  cluster_name = local.cluster_name
  machine_type = "worker"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${hcloud_load_balancer_network.this.ip}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = [for config in local.worker_configuration[each.key] : yamlencode(config)]
}
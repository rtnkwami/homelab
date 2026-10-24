locals {
  controlplane = {
    ip = {
      public = hcloud_load_balancer.this.ipv4
      private = hcloud_load_balancer_network.this.ip
    }
    bootstrap_ip = hcloud_server_network.controlplane[local.hcloud_zones[0]].ip
  }

  inline_manifests = [
    local.hcloud_secret_manifest,
    local.talos_ccm_manifest,
    local.hcloud_ccm_manifest,
    local.hcloud_csi_manifest,
    local.cilium_manifest,
    local.kube_metrics_server_manifest,
    local.cluster_autoscaler_manifest,
    local.asg_config_manifest
  ]

  controlplane_config = [
    {
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "tailscale"
      environment = [
        "TS_AUTHKEY=${var.tailscale_authkey}",
        "TS_ROUTES=${local.network_cidrs.app},${local.network_cidrs.db}",
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
          local.controlplane.ip.private,
          local.controlplane.ip.public
        ]
      }
      cluster = {
        externalCloudProvider = {
          enabled = true
        }
      }
    }
  ]
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name = "homelab"
  machine_type = "controlplane"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${local.controlplane.ip.private}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = concat(
    [for document in local.controlplane_config : yamlencode(document)],
    [for manifest in local.inline_manifests : yamlencode(manifest)]
  )
}

ephemeral "talos_cluster_kubeconfig" "this" {
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_name = "homelab"
  endpoint = "https://${local.controlplane.ip.private}:6443"
}

resource "talos_machine" "controlplane-0" {
  depends_on = [
    hcloud_server_network.tailscale_router_0,
    hcloud_server_network.tailscale_router_1
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane.machine_configuration
  # NOTE: talos_machine will upgrade control plane talos os if the talos version changes
  image = data.talos_image_factory_urls.talos_tailscale.urls.installer
  # NOTE: set this because talos_cluster handles k8s upgrades, while talos_machine handles talos upgrades
  ignore_kubernetes_upgrade_drift = true
  kubeconfig_wo = ephemeral.talos_cluster_kubeconfig.this.kubeconfig_raw
  
  node = hcloud_server_network.controlplane[local.hcloud_zones[0]].ip
}

resource "talos_machine" "controlplane-1" {
  depends_on = [talos_machine.controlplane-0]

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane.machine_configuration
  image = data.talos_image_factory_urls.talos_tailscale.urls.installer
  ignore_kubernetes_upgrade_drift = true
  kubeconfig_wo = ephemeral.talos_cluster_kubeconfig.this.kubeconfig_raw
 
  node = hcloud_server_network.controlplane[local.hcloud_zones[1]].ip
}

resource "talos_machine" "controlplane-2" {
  depends_on = [talos_machine.controlplane-1]

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane.machine_configuration
  image = data.talos_image_factory_urls.talos_tailscale.urls.installer
  ignore_kubernetes_upgrade_drift = true
  kubeconfig_wo = ephemeral.talos_cluster_kubeconfig.this.kubeconfig_raw
  
  node = hcloud_server_network.controlplane[local.hcloud_zones[2]].ip
}

resource "talos_cluster" "this" {
  depends_on = [talos_machine.controlplane-2]

  control_plane_nodes = [for node in hcloud_server_network.controlplane: node.ip]
  client_configuration = talos_machine_secrets.this.client_configuration
  kubernetes_version = local.versions.k8s

  node = hcloud_server_network.controlplane["hel1"].ip
  endpoint = local.controlplane.ip.private
}

data "talos_cluster_health" "this" {
  depends_on = [talos_cluster.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  # NOTE: I have no idea why, but if I set this to false, this healthcheck hangs forever
  skip_kubernetes_checks = true
  control_plane_nodes = [for node in hcloud_server_network.controlplane: node.ip]
  endpoints = [local.controlplane.ip.private]
}

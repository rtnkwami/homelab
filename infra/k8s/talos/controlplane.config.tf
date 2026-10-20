locals {
  controlplane = {
    ip = {
      public = hcloud_load_balancer.this.ipv4
      private = hcloud_load_balancer_network.this.ip
    }
    bootstrap_ip = hcloud_server_network.controlplane[local.hcloud_zones[0]].ip
  }

  talos_control_plane_config = {
    tailscale_extension_config = {
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "tailscale"
      environment = [
        "TS_AUTHKEY=${var.tailscale_authkey}",
        "TS_ROUTES=${local.network_config.cidrs.infra},${local.network_config.cidrs.controlplane}",
      ]
    }

    # NOTE:
    # This is set to prevent talos from discarding unusued container image layers
    # so that spegel can use them.
    cri_customization_config = {
      apiVersion = "v1alpha1"
      kind =  "CRICustomizationConfig"
      name = "prevent-image-layer-discarding"
      content = <<-EOF
        [plugins."io.containerd.cri.v1.images"]
        discard_unpacked_layers = false
      EOF
    }

    kubelet_config = {
      apiVersion = "v1alpha1"
      kind =  "KubeletConfig"
      config = {
        # NOTE: this setting replaces --rotate-server-certificates
        # It requires RotateKubeletServerCertificate to be set to true (which is its default)
        # REF: https://github.com/kubernetes/enhancements/pull/4411#:~:text=When%20the%20feature%20gate%20%60RotateKubeletServerCertificate%60%20is%20true%2C%20then%20%60ServerTLSBootstrap%60%20is%20also%20required%20to%20be%20true%2E,-To
        serverTLSBootstrap = true
      }
      # NOTE: 
      # Replace default network config with actual configured networking and subnets, as
      # network segregation needs to be implemented
      clusterDNS = [cidrhost(local.network_config.cidrs.k8s_services, 10)]
      extraArgs = {
        # NOTE: adds taint: node.cloudprovider.kubernetes.io/uninitialized to nodes during init
        # This marks the node as needing a second initialization from an external controller
        # before it can be scheduled work. This is important since the scheduler may require 
        # cloud specific information about nodes such as their region or type.
        cloud-provider = "external"
      }
    }

    kube_node_config = {
      apiVersion = "v1alpha1"
      kind =  "KubeNodeConfig"
      # NOTE: if this setting is not set, node IPs may be set from outside the configured CIDR range
      # for the cluster.
      nodeIP = {
        validSubnets = [local.network_config.cidrs.controlplane]
      }
    }

    # NOTE: needed for talos ccm to access talos from within the cluster
    kubernetes_talos_api_access = {
      apiVersion = "v1alpha1"
      kind =  "KubeTalosAPIAccessConfig"
      allowedRoles = ["os:reader"]
      allowedKubernetesNamespaces = ["kube-system"]
    }

    kube_network_config = {
      apiVersion = "v1alpha1"
      kind =  "KubeNetworkConfig"
      # NOTE:
      # enabling this causes kube-controller-manager settings:
      # --allocate-node-cidrs = true
      # --cluster-cidr = podSubnets
      podSubnets = [local.network_config.cidrs.k8s_pods]
      serviceSubnets = [local.network_config.cidrs.k8s_services]
      # NOTE:
      # The maximum node count in the node subnets would cause ip exhaustion if the
      # default pod count (~110) for k8s was used. Since the cluster pod cidr allocated
      # is not infinite, pod count per node has been reduced.
      nodeCIDRMaskSizeIPv4 = 26
    }

    # NOTE: disabled due to cilium installation
    kube_flannel_cni_config = {
      apiVersion = "v1alpha1"
      kind =  "KubeFlannelCNIConfig"
      "$patch" = "delete"
    }

    # NOTE: disabled due to cilium installation
    kube_proxy_config = {
      apiVersion = "v1alpha1"
      kind =  "KubeProxyConfig"
      enabled = false
    }

    # NOTE: this is used to configure service accounts for AWS IRSA
    # See irsa.config.tf
    kube_api_server_config = {
      apiVersion = "v1alpha1"
      kind =  "KubeServiceAccountConfig"
      issuer = {
        issuerURL = "https://${local._irsa_oidc_issuer}"
        privateKey = tls_private_key.service_account_signing_key.private_key_pem
      }
      accepted = {
        audiences = [local._irsa_oidc_audience]
      }
    }
  }

  extra_config = {
    machine = {
      # Use private ip of control plane load balancer to prevent talosctl access from passing
      # through the internet
      certSANs = [
        local.controlplane.ip.private,
        local.controlplane.ip.public
      ]
    }
    cluster = {
      controllerManager = {
        extraArgs = {
          cloud-provider = "external"
        }
      }

      externalCloudProvider = {
        enabled = true
      }
    }
  }
}

resource "talos_machine_secrets" "this" {
  talos_version = local.versions.talos
}

data "talos_machine_configuration" "controlplane" {
  cluster_name = "homelab"
  machine_type = "controlplane"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${local.controlplane.ip.private}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = concat(
    [for config, document in local.talos_control_plane_config : yamlencode(document) ],
    [
      yamlencode(local.extra_config),
      yamlencode(local.hcloud_secret_manifest),
      # Tools to install at bootstrap
      yamlencode(local.cilium_manifest),
      yamlencode(local.talos_ccm_manifest),
      yamlencode(local.hcloud_ccm_manifest),
      yamlencode(local.hcloud_csi_manifest),
      yamlencode(local.cluster_autoscaler_manifest)
    ]
  )
}

ephemeral "talos_cluster_kubeconfig" "this" {
  count = var.is_bootstrap ? 0 : 1

  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_name = "homelab"
  endpoint = "https://${local.controlplane.ip.private}:6443"
}

resource "talos_machine" "controlplane-0" {
  depends_on = [hcloud_server_network.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane.machine_configuration
  # NOTE: talos_machine will upgrade control plane talos os if the talos version changes
  image = data.talos_image_factory_urls.talos_tailscale.urls.installer
  # NOTE: set this because talos_cluster handles k8s upgrades, while talos_machine handles talos upgrades
  ignore_kubernetes_upgrade_drift = true
  drain_on_upgrade = var.is_bootstrap ? false : true
  kubeconfig_wo = var.is_bootstrap ? null : ephemeral.talos_cluster_kubeconfig.this[0].kubeconfig_raw
  
  node = hcloud_server_network.controlplane["hel1"].ip
  # NOTE:
  # Control plane nodes act as subnet routers to tailscale. Before tailscaled is active on the control
  # plane nodes, terraform needs to access the nodes somehow. That is what the public IP is for.
  # Once the cluster has been bootstrapped, var.is_bootstrap can be set to false to disable all
  # inbound public access, and only use tailscale for further operations.
  endpoint = var.is_bootstrap ? hcloud_server.controlplane["hel1"].ipv4_address : local.controlplane.ip.private
}

resource "talos_machine" "controlplane-1" {
  depends_on = [talos_machine.controlplane-0]

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane.machine_configuration
  image = data.talos_image_factory_urls.talos_tailscale.urls.installer
  ignore_kubernetes_upgrade_drift = true
  drain_on_upgrade = var.is_bootstrap ? false : true
  kubeconfig_wo = var.is_bootstrap ? null : ephemeral.talos_cluster_kubeconfig.this[0].kubeconfig_raw
 
  node = hcloud_server_network.controlplane["nbg1"].ip
  endpoint = var.is_bootstrap ? hcloud_server.controlplane["nbg1"].ipv4_address : local.controlplane.ip.private
}

resource "talos_machine" "controlplane-2" {
  depends_on = [talos_machine.controlplane-1]

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane.machine_configuration
  image = data.talos_image_factory_urls.talos_tailscale.urls.installer
  ignore_kubernetes_upgrade_drift = true
  drain_on_upgrade = var.is_bootstrap ? false : true
  kubeconfig_wo = var.is_bootstrap ? null : ephemeral.talos_cluster_kubeconfig.this[0].kubeconfig_raw
  
  node = hcloud_server_network.controlplane["fsn1"].ip
  endpoint = var.is_bootstrap ? hcloud_server.controlplane["fsn1"].ipv4_address : local.controlplane.ip.private
}

resource "talos_cluster" "this" {
  depends_on = [talos_machine.controlplane-2]

  control_plane_nodes = [for k, v in hcloud_server_network.controlplane: v.ip]
  client_configuration = talos_machine_secrets.this.client_configuration
  kubernetes_version = local.versions.k8s

  node = hcloud_server_network.controlplane["hel1"].ip
  endpoint = var.is_bootstrap ? hcloud_server.controlplane["hel1"].ipv4_address : local.controlplane.ip.private
}

data "talos_cluster_health" "this" {
  depends_on = [talos_cluster.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes = [for k, v in hcloud_server_network.controlplane: v.ip]
  endpoints = [var.is_bootstrap ? hcloud_server.controlplane["hel1"].ipv4_address : local.controlplane.ip.private]
}

locals {
  tailscale_config = {
    apiVersion = "v1alpha1"
    kind       = "ExtensionServiceConfig"
    name       = "tailscale"
    environment = [
      "TS_AUTHKEY=${var.tailscale_authkey}",
      "TS_ROUTES=${local.network_config.cidrs.infra},${local.network_config.cidrs.controlplane}",
    ]
  }

  controlplane = {
    ip = {
      public = hcloud_load_balancer.this.ipv4
      private = hcloud_load_balancer_network.this.ip
    }
    bootstrap_ip = hcloud_server_network.controlplane[local.hcloud_zones[0]].ip
  }

  controlplane_config = {
    machine = {
      # NOTE:
      # This is set to prevent talos from discarding unusued container image layers
      # so that spegel can use them.
      files = [
        {
          path = "/etc/cri/conf.d/20-customization.part"
          op = "create"
          content = <<-EOF
            [plugins."io.containerd.cri.v1.images"]
            discard_unpacked_layers = false
          EOF
        }
      ]
      # Use private ip of control plane load balancer to prevent talosctl access from passing
      # through the internet
      certSANs = [local.controlplane.ip.private]
      kubelet = {
        # NOTE: 
        # Replace default network config with actual configured networking and subnets, as
        # network segregation needs to be implemented
        clusterDNS = [cidrhost(local.network_config.cidrs.k8s_services, 10)]
        # NOTE:
        # If this config is not set, node IPs may be set from outside the configured CIDR range
        # for the cluster
        nodeIP = {
          validSubnets = [local.network_config.cidrs.controlplane]
        }
        extraArgs = {
          cloud-provider = "external"
        }
      }
    }
    cluster = {
      network = {
        # NOTE:
        # enabling this causes kube-controller-manager settings:
        # --allocate-node-cidrs = true
        # --cluster-cidr = podSubnets
        podSubnets = [local.network_config.cidrs.k8s_pods]
        serviceSubnets = [local.network_config.cidrs.k8s_services]
        # use cilium instead of default cni
        cni = {
          name = "none"
        }
      }
      # disable kube-proxy in favor of cilium
      proxy = {
        disabled = true
      }
      # NOTE:
      # See irsa.config.tf
      apiServer = {
        extraArgs = {
          service-account-issuer = "https://${local._irsa_oidc_issuer}"
          api-audiences = local._irsa_oidc_audience
        }
      }
      serviceAccount = {
        key = base64encode(tls_private_key.service_account_signing_key.private_key_pem)
      }
      controllerManager = {
        extraArgs = {
          # NOTE:
          # The maximum node count in the node subnets would cause ip exhaustion if the
          # default pod count (~110) for k8s was used. Since the cluster pod cidr allocated
          # is not infinite, pod count per node has been reduced.
          node-cidr-mask-size-ipv4 = "26"
          cloud-provider = "external"
        }
      }
      inlineManifests = concat(
        [local.cni_manifest],
        [local.hcloud_secret_manifest],
        [local.ccm_manifest],
        [local.csi_manifest],
        [local.autoscaler_manifest],
      )
      externalCloudProvider = {
        enabled = true
        manifests = [
          "https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.versions.gwAPI}/experimental-install.yaml"
        ]
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
  config_patches = [
    yamlencode(local.tailscale_config),
    yamlencode(local.controlplane_config)
  ]
}

resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [hcloud_server_network.controlplane]
  for_each = hcloud_server.controlplane

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node = hcloud_server_network.controlplane[each.key].ip
  # NOTE:
  # Control plane nodes act as subnet routers to tailscale. Before tailscaled is active on the control
  # plane nodes, terraform needs to access the nodes somehow. That is what the public IP is for.
  # Once the cluster has been bootstrapped, var.is_bootstrap can be set to false to disable all
  # inbound public access, and only use tailscale for further operations.
  endpoint = var.is_bootstrap ? local.controlplane.ip.public : local.controlplane.ip.private
}

resource "talos_machine_bootstrap" "controlplane" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  node = local.controlplane.bootstrap_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

# Give the cluster time to initialize
resource "time_sleep" "this" {
  depends_on = [talos_machine_bootstrap.controlplane]
  create_duration = "2m"
}
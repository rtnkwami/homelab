locals {
  talos_worker_config = {
    for pool in local._autoscaler_nodepools : pool.name => {
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
          registerWithTaints = pool.taints
        }
        # NOTE:
        # if this isn't set on worker nodes, kubelet on worker nodes will
        # try to reach kube-dns on the hardcoded original config which would
        # cause them to timeout with an old ip.
        clusterDNS = [cidrhost(local.network_config.cidrs.k8s_services, 10)]
        extraArgs = {
          cloud-provider = "external"
        }
      }
    }
  }

  worker_config = {
    # Generate a machine config for each autoscaling group configured for cluster autoscaler
    for pool in local._autoscaler_nodepools : pool.name => [{
      machine = {
        nodeLabels = pool.labels
      }
    }]
  }
}

data "talos_machine_configuration" "worker" {
  for_each = { for pool in local._autoscaler_nodepools : pool.name => pool }
  
  cluster_name = "homelab"
  machine_type = "worker"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_endpoint = "https://${local.controlplane.ip.private}:6443"
  talos_version = local.versions.talos
  kubernetes_version = local.versions.k8s
  config_patches = concat(
    [for config in local.worker_config[each.key] : yamlencode(config)],
    [for config in local.talos_worker_config[each.key] : yamlencode(config)]
  )
}

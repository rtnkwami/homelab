# Homelab Kubernetes Cluster

## Overview

This cluster is a self-hosted Kubernetes cluster running on [Talos Linux](https://talos.dev), hosted on Hetzner Cloud. It is meant for my personal homelab. Because it's a part of my homelab, cost is a big constraint. As such much of the more expensive items (e.g. compute) in this lab use Hetzner on AWS, while AWS is used for all other services/tools that are not as expensive.

The cluster is fully private. There is public ingress; the only way to reach the cluster (API server, workloads, dashboards, etc.) is over a [Tailscale](https://tailscale.com) tailnet.

Provisioning and configuration are split into three layers, each living in its own subdirectory:

* `infra/`: Terraform that provisions the control plane, networking, and cluster level components on Hetzner.

* `os/`: Terraform that builds the Talos OS images (server snapshots) used by cluster nodes.

* `gitops/`: ArgoCD configuration; once bootstrapped, this is the preferred way to deploy workloads and add-ons into the cluster

Everything past initial bootstrap is driven via GitOps. The only manual step is the initial ArgoCD install itself.

## Directory Structure

* `infra/` components:

  * Hetzner servers, firewalls, and the load balancer fronting the control plane

  * The Talos cluster itself

  * Cilium, Hetzner CCM, Hetzner CSI, and Cluster Autoscaler configuration

  * Node pool definitions consumed by the Cluster Autoscaler

  * A self-hosted Talos/Kubernetes OIDC setup: this project generates the OIDC discovery config and JWKS, embeds them into the Talos machine config (rather than letting Kubernetes generate them itself), and publishes them to a public S3 bucket so AWS STS can validate tokens against them. This is what makes IRSA possible on a non-EKS cluster (see [Secrets & IAM]()).

  * An IAM role for the [ACK IAM Controller](https://github.com/aws-controllers-k8s/iam-controller), which is installed later via GitOps. Once that controller is running, IRSA roles are managed as Kubernetes CRDs instead of through Terraform or the AWS console.

* `os/` components:

  A separate Terraform project that builds Talos OS snapshots via the [`hcloud-talos/imager`](https://registry.terraform.io/providers/hcloud-talos/imager/latest) provider:

  * A raw Talos snapshot

  * A Talos snapshot with the Tailscale system extension baked in
  
  This is run infrequently, usually only when upgrading the Talos version, and is separated from `infra/` since it doesn't need to run on every apply.

* `gitops/` components:

  Once the control plane is up, `argocd-install.yaml` is applied manually (via a `mise run //cluster:bootstrap`) to bootstrap ArgoCD. From that point forward, ArgoCD owns the rest of the cluster:

  * `app-of-apps.yaml` is the root ArgoCD Application, pointing at `gitops/manifests`

  * Every file in `manifests/` is itself an ArgoCD Application.

  * One of these, [`genesis`](/helm/genesis/Chart.yaml), deploys a Helm chart (`helm/genesis`) containing the foundational cluster-wide components

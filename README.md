## Overview

This is a mono-repository for my personal projects. The purpose of this repository is to learn and understand Infrastructure-as-Code (IaC), Continuous Integration/Continuous Delivery (CI/CD), cloud infrastructure, container security and GitOps.

I also use this repository to play around with languages and technologies I find interesting, or that aren't as common as some of the other tech out there.

I've designed this README to walk you through the structure of the repository. It provides a high-level overview of what I've been doing here, as well as where to find any information that may interest you.

I've put my [post-mortems](https://www.pagerduty.com/resources/digital-operations/learn/incident-postmortem/), times when I've had issues, either with my clusters or with my applications, and had to make certain design or architectural decisions, here, as well as my experiments and tests.

A table of contents has been prepared below to give you a faster way to find what you're looking for:

---

## Table of Contents

- [Kubernetes](#kubernetes)
  - [Core Components](#core-components)
  - [Network Architecture](#network-architecture)
- [Post-mortems](#post-mortems)
- [Architectural Decisions](#architectural-decisions)
- [Applications](#applications)

---

## Kubernetes

I have 2 Kubernetes clusters currently configured in this mono-repository. One of them is deployed using [Talos](https://www.talos.dev) on Hetzner Cloud, and the other is deployed using [AWS Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks). Both clusters use almost the same components, except where technical or cost constraints require that some components be switched out for alternatives.

### Core Components

- **Networking & Ingress:**

  - [Cilium](https://github.com/cilium/cilium) provides eBPF networking for pods in the cluster.
  - [Istio](https://istio.io) provides GatewayAPI functionality for L7 through the `app-gateway` Gateway, mTLS for application workloads, and waypoints for services working with gRPC.
  - [Tailscale](https://tailscale.com/) provides private networking for services within the clusters, and for the cluster deployed using Talos, it also provides a way to prevent traffic over the public internet to control plane nodes (more on this architecture later).

- **Security & Secrets:**

  - [cert-manager](https://cert-manager.io) automates SSL/TLS certificate management.
  - [External Secrets Operator](https://external-secrets.io/latest/) is used with [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) for secrets.
  - [Amazon EKS Pod Identity Webhook](https://github.com/aws/amazon-eks-pod-identity-webhook) provides access to AWS services through [AWS IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).

- **Storage:**

  - The respective cloud service providers' CSI drivers are used for PVCs in the clusters. [Spegel](https://spegel.dev/) runs a stateless OCI mirror on both clusters.

- **DNS:**

  - [ExternalDNS](https://kubernetes-sigs.github.io/external-dns/) is used to manage hostnames through which the services running within my cluster are exposed to the internet. Cloudflare is my DNS provider and domain registrar of choice, due to their extensive and cheap protections.

- **Automation & CI/CD:**

  - GitHub Actions is used for CI.
  - [Flux Operator](https://fluxoperator.dev/) is used to manage FluxCD, which is used for GitOps.
  - OpenTofu handles cluster upgrades.
  - [Kube-descheduler](https://github.com/kubernetes-sigs/descheduler) ensures scheduled pods in the cluster honor their scheduling rules even after cluster drift.

- **Observability:**

  - The [victoria-metrics-k8s-stack](https://docs.victoriametrics.com/helm/victoria-metrics-k8s-stack/) toolkit is being used for handling logs and metrics across the entire cluster.

### Network Architecture

<details>
  <summary>Network diagram will be created soon (Date this was written: 25/11/2026)</summary>
</details>

---

## Post-mortems

- [Cilium Proxy Protocol Breaks Tailscale Gateway](/docs/post-mortems/cilium_proxy_protocol_issues.md)
- [Victoria Metrics Stuck on Delete](/docs/post-mortems/victoria_metrics_stuck_on_delete.md)

---

## Architectural Decisions

- [Migrate from ArgoCD to FluxCD](/docs/decisions/migrate_from_argocd_to_fluxcd.md)
- [Secure Kubernetes and Talos API Access via Private Tailscale Networking](/docs/decisions/secure_k8s_api_access_over_tailscale.md)

---

## Applications

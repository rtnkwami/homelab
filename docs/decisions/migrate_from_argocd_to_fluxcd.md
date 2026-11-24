# Migrate from ArgoCD to Flux Operator & FluxCD

## Summary

**Date:** 12th October, 2026

**Rationale:**

As the title says, I decided to migrate from ArgoCD to FluxCD for the reasons stated below:

When bootstrapping a cluster, I had multiple tools and applications (platform-level apps) that needed to be installed in the cluster before any other workloads (app-level workloads) could run. Some of these components included cert-manager, external secrets operator, external-dns, among others.

During bootstrap, I ran into the problem where some tools needed custom resources that could only be deployed after the CRDs of prior tools were installed. ArgoCD sync waves should have resolved this issue, however, I found it increasingly difficult to create a map of what dependencies certain cluster resources had.

As a result, there were multiple instances of misconfigurations where some resources should have come before others, but because there were so many custom resources to manage in my repository, I lost track of them and had to rely on ArgoCD sync errors to catch misconfigurations.

Flux Operator along with FluxCD resolved this issue for me with `ResourceSets`. A resourceset allowed me to group relevant manifests, as well as to explicitly declare dependencies between any custom resources within the cluster, without having to mentally remember which resources were in which sync waves.

In addition, I found the FluxCD CRDs from the Source, Helm, and Kustomize controllers to be much easier to reason about than ArgoCD Applications and ApplicationSets.

**Trade-offs:**

- I no longer have access to the ArgoCD UI to see what has been deployed. However, this is offset by the Flux Operator UI, as well as TUI applications such as [sofka](https://sofka.rs/).

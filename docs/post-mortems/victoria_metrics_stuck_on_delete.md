# Victoria Metrics Stuck on Delete

## Details (Date: 8th July, 2026)

### Description

During clean-up after a dev session in my homelab, I ran a delete of the tools deployed via GitOps in my cluster (when I was running ArgoCD and not FluxCD), by deleting the app-of-apps. Upon delete, the operation hung forever and never progressed.

### Investigation

- During my investigation I checked:

  - ArgoCD sync logs
  - Victoria Metrics Operator logs
  - Kubernetes cluster events

  My investigation led to zero results from these sources. However, a Google search turned up some results. During the deletion of the `victoria-metrics-k8s-stack`, the helm chart cannot guarantee the order of resource deletion ([Issue 1563](https://github.com/VictoriaMetrics/helm-charts/issues/1563)).

- The Victoria Metrics Operator is installed as a part of the stack, and is the "brain" of the entire observability system. During the installation of the helm chart, a finalizer is placed on resources in the helm chart that only the operator can remove.

- However, during deletion, it is possible for the operator to be deleted before the resources it manages, thereby leaving ArgoCD no method for the removal of these resources, unless you manually remove the finalizers.

### Resolution

To resolve this issue, I deployed the Victoria Metrics Operator and the `victoria-metrics-k8s-stack` helm chart separately, and disabled the operator in the k8s-stack helm chart. This makes it possible to control the deletion order of the chart and the operator.

I also deployed the operator in a different namespace from the k8s-stack helm chart. This prevents the entire observability namespace from being deleted.

Finally, I setup sync waves so that the Victoria Metrics Operator would be synced before the k8s-stack helm chart is deployed, and would be deleted last, after the k8-stack has been cleaned up.

The Victoria Metrics documentation has also been updated to reflect the GitHub issue that was raised. It can be found [at this link](https://docs.victoriametrics.com/helm/victoria-metrics-k8s-stack/#install-operator-separately).

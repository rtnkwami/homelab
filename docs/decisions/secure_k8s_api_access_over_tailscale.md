# Secure Kubernetes and Talos API Access with Tailscale

## Details (Date: 8th November, 2026)

### Rationale

During the first iteration of my Talos cluster's architecture, I exposed my control plane nodes to the internet, to allow my Terraform runner access to the nodes to run upgrades and configuration changes on control plane nodes.

In later iterations, I tightened network access a bit more by attaching firewalls to each of my servers, and allowing inbound access to my control plane nodes only via Terraform runner's IP. The issue I ran into with this was that the runner's IP changed between runs. This made it such that every Terraform plan would show that the firewall rules had to change to suit the current IP of the runner.

In addition, after each run of Terraform, the IP that was allow-listed would migrate to another runner I had no control over, posing a security risk. This security risk was something I did not really consider to be that large, especially since both the kube-api and talos-api are protected by mTLS. However, since zero-days are possible in either APIs, I wanted to ensure I closed this gap.

Tailscale proved to be a good solution. It allowed me to expose kubernetes API access over my own private network for my own personal admin access. I was also able to make my Terraform runners join my own private tailnet as [ephemeral nodes](https://tailscale.com/docs/features/ephemeral-nodes), so that control plane upgrades and other configurations could pass through the private tailnet.

### Trade-offs

I have not yet discovered any trade-offs with my current approach.

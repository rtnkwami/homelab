# Cilium Proxy Protocol Setting Breaks Tailscale Gateway

## Details (Date: 9th July, 2026)

### Description

Initially, I was using Cilium Gateway API. After setting `enableProxyProtocol` to true on Cilium traffic on my tailscale gateway for traffic on my tailnet began to be dropped. This broke access to Grafana over Tailscale.

### Investigation

- I did some research on Cilium's proxy protocol setting and discovered that it is enabled for all gateways created using the cilium gateway class ([Issue #41876](https://github.com/cilium/cilium/issues/41876)). Due to this, any other gateways I create which use the cilium gateway class but do not use proxy protocol will have their traffic dropped for as long as that global setting is enabled in the helm chart.

- Because the Tailscale gateway currently does not add a proxy protocol header to the traffic it forwards, Cilium drops its packets, since it expects that header. The GitHub issue referenced above, at the time of writing this post-mortem is currently not implemented, and as such it presents a significant barrier to my usage of Cilium's implementation of Gateway API.

### Resolution

I eventually decided to migrate my internal traffic which passes through Tailscale to Envoy Gateway and preserve the traffic which requires proxy protocol on Cilium. However, after running this setup for some time, I realized that running multiple Gateway API controllers was tedious, since I had to manage two separate systems.

I later decided to go for Istio Ambient Mode and consolidate all Gateway API implementations into one system. Going Ambient Mode also provides mTLS by default for all mesh enabled systems, and allows me to play around with using Envoy waypoints for apps with gRPC.

resource "imager_image" "x86_image" {
  image_url = "https://factory.talos.dev/image/${var.talos_schematic_id}/v${var.talos_version}/hcloud-amd64.raw.xz"
  architecture = "x86"
  # if you use a bigger server, and the k8s cluster tries to spin up a smaller server during
  # autoscaling, an error will be thrown, causing failures.
  server_type = "cx23"
  location = "fsn1"
  description = "homelab_node_x86_image"

  timeouts {
    create = "10m"
  }

  labels = {
    os = "talos"
    arch = "x86"
  }
}
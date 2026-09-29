locals {
  talos_version = "v1.13.9"
}

data "talos_image_factory_extensions_versions" "talos_tailscale" {
  talos_version = local.talos_version
  filters = {
    names = ["tailscale"]
  }
}

resource "talos_image_factory_schematic" "talos_tailscale" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.talos_tailscale.extensions_info.*.name
      }
    }
  })
}

data "talos_image_factory_urls" "talos_tailscale" {
  talos_version = local.talos_version
  schematic_id = talos_image_factory_schematic.talos_tailscale.id
  platform = "hcloud"
}

resource "imager_image" "talos_tailscale" {
  image_url = "${data.talos_image_factory_urls.talos_tailscale.urls.disk_image}"
  architecture = "x86"
  description = "talos_tailscale_x86"
  labels = {
    os = "talos-tailscale"
  }
  
  timeouts {
    create = "10m"
  }
}

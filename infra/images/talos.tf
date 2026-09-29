resource "talos_image_factory_schematic" "talos_x86" {
  schematic = yamlencode({})
}

data "talos_image_factory_urls" "talos_x86" {
  talos_version = local.talos_version
  schematic_id = talos_image_factory_schematic.talos_x86.id
  platform = "hcloud"
}

resource "imager_image" "talos_x86" {
  image_url = "${data.talos_image_factory_urls.talos_x86.urls.disk_image}"
  architecture = "x86"
  description = "talos_x86"
  labels = {
    os = "talos"
  }
  
  timeouts {
    create = "10m"
  }
}

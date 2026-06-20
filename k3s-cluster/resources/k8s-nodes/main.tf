locals {
  # node -> distinct storage disk types (e.g. ["nvme", "ssd"]), nodes with disks only.
  node_types = {
    for name, n in var.nodes : name => distinct([for d in try(n.data_disks, []) : d.type])
    if length(try(n.data_disks, [])) > 0
  }
}

# Storage-type labels live here (admin server-side apply) because the
# storage.kubernetes.io/ prefix is reserved by NodeRestriction and a node may
# not self-label it at join. force adopts the field from the previous kubectl
# owner.
resource "kubernetes_labels" "storage" {
  for_each = local.node_types

  api_version   = "v1"
  kind          = "Node"
  field_manager = "terraform"
  force         = true

  metadata {
    name = each.key
  }

  labels = { for t in each.value : "storage.kubernetes.io/${t}" => "true" }
}

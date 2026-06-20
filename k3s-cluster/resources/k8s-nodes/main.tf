locals {
  node_types = {
    for name, n in var.nodes : name => distinct([for d in try(n.data_disks, []) : d.type])
    if length(try(n.data_disks, [])) > 0
  }
}

# storage.kubernetes.io/ is reserved by NodeRestriction, so nodes can't
# self-label it at join; apply as admin. force takes the field from kubectl.
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

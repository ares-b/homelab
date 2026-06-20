locals {
  layers = toset(["raw", "master", "product"])
}

resource "garage_bucket" "lakehouse" {
  for_each = local.layers
  global_alias = "lakehouse-${each.key}"
}

locals {
  layers = toset(["raw", "master", "product"])
}

resource "garage_bucket" "lakehouse" {
  for_each     = local.layers
  global_alias = "lakehouse-${each.key}"
}

# Single warehouse for the Iceberg SQL catalog; table data and metadata live here.
resource "garage_bucket" "warehouse" {
  global_alias = "lakehouse-warehouse"
}

resource "garage_key" "lakehouse" {
  for_each = local.layers
  name     = "lakehouse-${each.key}-key"
}

locals {
  bucket_key_permissions = {
    "raw-on-raw"         = { key = "raw", bucket = "raw", read = false, write = true }
    "master-on-raw"      = { key = "master", bucket = "raw", read = true, write = false }
    "master-on-master"   = { key = "master", bucket = "master", read = true, write = true }
    "product-on-master"  = { key = "product", bucket = "master", read = true, write = false }
    "product-on-product" = { key = "product", bucket = "product", read = false, write = true }
  }
}

resource "garage_bucket_permission" "lakehouse" {
  for_each      = local.bucket_key_permissions
  bucket_id     = garage_bucket.lakehouse[each.value.bucket].id
  access_key_id = garage_key.lakehouse[each.value.key].id
  read          = each.value.read
  write         = each.value.write
  owner         = false
}

# Iceberg uses one catalog over all namespaces, so a single key with read/write on the warehouse.
resource "garage_key" "iceberg" {
  name = "iceberg-key"
}

resource "garage_bucket_permission" "iceberg" {
  bucket_id     = garage_bucket.warehouse.id
  access_key_id = garage_key.iceberg.id
  read          = true
  write         = true
  owner         = false
}

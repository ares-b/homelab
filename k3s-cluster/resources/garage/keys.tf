resource "garage_key" "lakehouse" {
  for_each = local.layers
  name     = "lakehouse-${each.key}-key"
}

locals {
  bucket_key_permissions = {
    "raw-write-raw"         = { key = "raw",     bucket = "raw",     read = false, write = true }
    "master-read-raw"       = { key = "master",  bucket = "raw",     read = true,  write = false }
    "master-write-master"   = { key = "master",  bucket = "master",  read = false, write = true }
    "product-read-master"   = { key = "product", bucket = "master",  read = true,  write = false }
    "product-write-product" = { key = "product", bucket = "product", read = false, write = true }
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

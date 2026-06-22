resource "garage_key" "this" {
  for_each = toset(var.keys)
  name     = each.value
}

resource "garage_bucket_permission" "this" {
  for_each = { for p in var.permissions : "${p.key}-on-${p.bucket}" => p }

  bucket_id     = garage_bucket.this[each.value.bucket].id
  access_key_id = garage_key.this[each.value.key].id
  read          = each.value.read
  write         = each.value.write
  owner         = each.value.owner
}

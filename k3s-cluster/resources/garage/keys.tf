# Lakekeeper holds this key and remote-signs S3 requests; clients never receive it.
resource "garage_key" "warehouse" {
  name = "lakehouse-warehouse-key"
}

resource "garage_bucket_permission" "warehouse" {
  bucket_id     = garage_bucket.warehouse.id
  access_key_id = garage_key.warehouse.id
  read          = true
  write         = true
  owner         = false
}

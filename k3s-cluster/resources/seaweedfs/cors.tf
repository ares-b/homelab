resource "aws_s3_bucket_cors_configuration" "this" {
  for_each = { for c in var.cors : c.bucket => c }
  bucket   = aws_s3_bucket.this[each.value.bucket].id

  cors_rule {
    allowed_origins = each.value.allowed_origins
    allowed_methods = each.value.allowed_methods
    allowed_headers = each.value.allowed_headers
    expose_headers  = each.value.expose_headers
    max_age_seconds = each.value.max_age_seconds
  }
}

resource "aws_s3_bucket" "this" {
  for_each = toset(var.buckets)
  bucket   = each.value
}

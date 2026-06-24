output "bucket_ids" {
  description = "Bucket names by key."
  value       = { for name, bucket in aws_s3_bucket.this : name => bucket.id }
}

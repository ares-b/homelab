output "bucket_names" {
  description = "Lakehouse bucket names."
  value       = { for layer, bucket in garage_bucket.lakehouse : layer => bucket.global_alias }
}

output "key_ids" {
  description = "Access key IDs per layer."
  sensitive   = true
  value       = { for layer, key in garage_key.lakehouse : layer => key.id }
}

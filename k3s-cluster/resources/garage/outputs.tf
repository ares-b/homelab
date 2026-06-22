output "key_ids" {
  description = "Access key IDs by key name."
  sensitive   = true
  value       = { for name, key in garage_key.this : name => key.id }
}

output "key_secrets" {
  description = "Secret access keys by key name."
  sensitive   = true
  value       = { for name, key in garage_key.this : name => key.secret_access_key }
}

output "bucket_ids" {
  description = "Bucket IDs by global alias."
  value       = { for alias, bucket in garage_bucket.this : alias => bucket.id }
}

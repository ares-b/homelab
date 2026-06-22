# Used once to register the warehouse storage credential in Lakekeeper.
output "warehouse_key_id" {
  description = "Warehouse access key ID."
  sensitive   = true
  value       = garage_key.warehouse.id
}

output "warehouse_key_secret" {
  description = "Warehouse secret access key."
  sensitive   = true
  value       = garage_key.warehouse.secret_access_key
}

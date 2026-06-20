output "node_labels" {
  description = "Storage labels applied per node."
  value       = { for name, types in local.node_types : name => [for t in types : "storage.kubernetes.io/${t}"] }
}

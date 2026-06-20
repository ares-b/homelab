output "users" {
  description = "Reconciled usernames and their cluster roles."
  value       = { for name, u in var.k8s_users : name => u.cluster_role }
}

variable "garage_admin_endpoint" {
  type        = string
  default     = "http://localhost:3903"
  description = "Garage admin API endpoint. Requires port-forward before apply: kubectl port-forward svc/garage 3903:3903 -n garage"
}

variable "garage_admin_token" {
  type        = string
  sensitive   = true
  description = "Garage admin API token (from garage-admin secret)."
}

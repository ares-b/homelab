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

variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/homelab-admin.yaml"
  description = "Kubeconfig used by kubectl and kubeseal when generating sealed secrets."
}

variable "s3_endpoint_url" {
  type        = string
  default     = "http://garage.garage.svc.cluster.local:3900"
  description = "In-cluster S3 endpoint injected into sealed secrets."
}

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

variable "buckets" {
  type        = list(string)
  default     = []
  description = "Bucket global aliases to create."
}

variable "keys" {
  type        = list(string)
  default     = []
  description = "Access key names to create."
}

variable "permissions" {
  type = list(object({
    key    = string
    bucket = string
    read   = optional(bool, false)
    write  = optional(bool, false)
    owner  = optional(bool, false)
  }))
  default     = []
  description = "Grants of a key's access to a bucket."
}

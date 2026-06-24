variable "seaweedfs_s3_endpoint" {
  type        = string
  default     = "http://localhost:8333"
  description = "SeaweedFS S3 endpoint. Requires port-forward before apply: kubectl port-forward svc/seaweedfs-s3 8333:8333 -n seaweedfs"
}

variable "seaweedfs_admin_access_key" {
  type        = string
  sensitive   = true
  description = "Access key of the SeaweedFS admin identity (from the seaweedfs-s3-config secret)."
}

variable "seaweedfs_admin_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key of the SeaweedFS admin identity."
}

variable "buckets" {
  type        = list(string)
  default     = []
  description = "Buckets to create."
}

variable "cors" {
  type = list(object({
    bucket          = string
    allowed_origins = list(string)
    allowed_methods = optional(list(string), ["GET", "HEAD"])
    allowed_headers = optional(list(string), ["*"])
    expose_headers  = optional(list(string), ["ETag"])
    max_age_seconds = optional(number, 3000)
  }))
  default     = []
  description = "CORS rules per bucket. Needed for the browser DuckDB engine."
}

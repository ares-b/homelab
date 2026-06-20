variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/homelab-admin.yaml"
  description = "Admin kubeconfig used to apply node labels."
}

# Same node map as provision/production (config.sops.yaml). Only
# data_disks[].type is read, hence any.
variable "nodes" {
  type = any
}

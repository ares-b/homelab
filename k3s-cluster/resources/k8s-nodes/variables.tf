variable "kubeconfig_path" {
  type        = string
  description = "Admin kubeconfig used to apply node labels."
}

# Only data_disks[].type is read, hence any.
variable "nodes" {
  type = any
}

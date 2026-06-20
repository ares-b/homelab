variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/homelab-admin.yaml"
  description = "Admin kubeconfig used to apply node labels."
}

# Same node map provision/production consumes, injected from config.sops.yaml
# (k3s_provision section) via the Makefile. Only data_disks[].type is read here.
variable "nodes" {
  type = any
}

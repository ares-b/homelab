variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/homelab-admin.yaml"
  description = "Admin kubeconfig used to reconcile users."
}

variable "k8s_users" {
  type = map(object({
    cluster_role = optional(string, "cluster-admin")
  }))
  default = {
    ares = { cluster_role = "cluster-admin" }
  }
  description = "Kubernetes users to reconcile. Key is the username. Use 'make k3s-kubeconfig' to write ~/.kube/config from the issued token."
}

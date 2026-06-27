variable "kubeconfig_path" {
  type        = string
  description = "Admin kubeconfig used to reconcile users."
}

variable "k8s_users" {
  type = map(object({
    cluster_role = optional(string, "cluster-admin")
  }))
  description = "Kubernetes users to reconcile. Key is the username, value sets the bound ClusterRole."
}

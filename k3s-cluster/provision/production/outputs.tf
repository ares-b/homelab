output "nodes" {
  description = "Cluster nodes with role and address."
  value = {
    for name, n in var.nodes : name => {
      role = n.role
      ip   = split("/", n.ip)[0]
    }
  }
}

output "server_ip" {
  description = "Control-plane address (kube API on :6443)."
  value       = local.server_ip
}

output "k8s_users" {
  description = "Kubernetes users to reconcile. Consumed by 'make configure'."
  value       = var.k8s_users
}

output "kubeconfig_command" {
  description = "Fetch the kubeconfig and point it at the server."
  value       = "ssh ops@${local.server_ip} sudo cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/${local.server_ip}/' > k3s.yaml"
}

locals {
  labels = { "app.kubernetes.io/managed-by" = "terraform" }
}

resource "kubernetes_service_account_v1" "user" {
  for_each = var.k8s_users

  metadata {
    name      = each.key
    namespace = "kube-system"
    labels    = local.labels
  }
}

# Static token Secret bound to the ServiceAccount. The provider waits for the
# token controller to populate it, so 'make k3s-kubeconfig' can read it right
# after apply.
resource "kubernetes_secret_v1" "token" {
  for_each = var.k8s_users

  metadata {
    name      = "${each.key}-token"
    namespace = "kube-system"
    labels    = local.labels
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.user[each.key].metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_binding_v1" "user" {
  for_each = var.k8s_users

  metadata {
    name   = "${each.key}-binding"
    labels = local.labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = each.value.cluster_role
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.user[each.key].metadata[0].name
    namespace = "kube-system"
  }
}

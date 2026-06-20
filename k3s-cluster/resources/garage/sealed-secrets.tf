locals {
  gitops_dagster_dir = "${path.root}/../../gitops/infrastructure/apps/dagster"
  kubeseal_cmd       = "KUBECONFIG=${var.kubeconfig_path} kubeseal --controller-namespace=sealed-secrets --format=yaml"

  layer_read_bucket = {
    raw     = ""
    master  = "lakehouse-raw"
    product = "lakehouse-master"
  }
}

resource "null_resource" "sealed_s3" {
  for_each = local.layers

  triggers = {
    key_id     = garage_key.lakehouse[each.key].id
    key_secret = garage_key.lakehouse[each.key].secret_access_key
  }

  provisioner "local-exec" {
    environment = {
      KEY_ID     = garage_key.lakehouse[each.key].id
      KEY_SECRET = garage_key.lakehouse[each.key].secret_access_key
    }
    command = <<-EOT
      KUBECONFIG=${var.kubeconfig_path} kubectl create secret generic s3-${each.key}-secret \
        --namespace=dagster \
        --from-literal=AWS_ACCESS_KEY_ID="$KEY_ID" \
        --from-literal=AWS_SECRET_ACCESS_KEY="$KEY_SECRET" \
        --from-literal=S3_ENDPOINT_URL="${var.s3_endpoint_url}" \
        --from-literal=S3_BUCKET="lakehouse-${each.key}" \
        ${local.layer_read_bucket[each.key] != "" ? "--from-literal=S3_BUCKET_READ=\"${local.layer_read_bucket[each.key]}\"" : ""} \
        --dry-run=client -o yaml | \
      ${local.kubeseal_cmd} > ${local.gitops_dagster_dir}/sealed-s3-${each.key}-secret.yaml
    EOT
  }

  depends_on = [garage_bucket_permission.lakehouse]
}

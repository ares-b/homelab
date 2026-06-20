# k3s-cluster

Terraform provisions a k3s cluster on Proxmox from the `ubuntu-k3s` Packer template. Node specs are configured in `terraform.tfvars` — see `variables.tf` for all options.

## Prerequisites

- `ubuntu-k3s` template built (VM ID matches `template_vm_id`, default 9000)
- `snippet_datastore_id` has the `snippets` content type enabled
- API token for `terraform@pve` (role `TerraformProvisioner`)

## Usage

```sh
make k3s-plan    # from repo root
make k3s-apply
```

Secrets are injected from the root `config.sops.yaml` (k3s_provision section). Always run through `make` — it injects both the sops secrets and the SSH CA public key from `ssh-ca/workload/ca.pub`. A bare `terraform apply` is rejected.

After apply:

```sh
make k3s-bootstrap    # flux + sealed-secrets + garage layout
make k3s-kubeconfig   # write ~/.kube/config for $USER
```

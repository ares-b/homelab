# k3s-cluster

Terraform provisions a k3s cluster on Proxmox from the `ubuntu-k3s` Packer template. Node specs live in the `nodes` variable — see `variables.tf` for all options. k3s installs via cloud-init on first boot (bootstrap only). Host config (disk LVM, firewall) converges via Ansible; cluster objects (k8s users, node labels) are managed declaratively by the Terraform roots under `../../resources`.

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
make k3s-configure    # ansible: node prep, disk LVM, firewall
make k3s-users-apply  # terraform: k8s ServiceAccounts + RBAC
make k3s-nodes-apply  # terraform: node storage labels
make k3s-bootstrap    # flux + sealed-secrets + garage layout
make k3s-kubeconfig   # write ~/.kube/config for $USER (reads the issued token)
```

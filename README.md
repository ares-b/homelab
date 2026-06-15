# homelab

Proxmox homelab — 3-node k3s cluster managed with Flux CD GitOps.

```
packer/           VM templates (ubuntu-k3s, ubuntu-docker)
pve-bootstrap/    Ansible — PVE host hardening
ssh-ca/           SSH certificate authorities
k3s-cluster/
  provision/      Terraform — VMs, disks, k8s users
  gitops/         Flux CD manifests
scripts/          Provisioning scripts
```

## Bootstrap order

```sh
ssh-ca/init.sh        # generate SSH CAs (once)
make pve-bootstrap    # harden PVE host
make images           # build VM templates
make k3s-apply        # provision VMs
make k3s-bootstrap    # flux + sealed-secrets + garage
```

## Makefile

| target | description |
|--------|-------------|
| `images` | build all Packer VM templates |
| `image-k3s` | k3s node template only |
| `image-docker` | docker host template only |
| `k3s-plan` | terraform plan |
| `k3s-apply` | provision VMs, disks, k8s users |
| `k3s-destroy` | terraform destroy |
| `k3s-bootstrap` | flux bootstrap + restore sealed-secrets key + garage layout |
| `k3s-garage-layout` | re-initialize garage cluster layout (idempotent) |
| `k3s-kubeconfig` | write kubeconfig for `K8S_USER` (default: `$USER`) |
| `k3s-kubeconfig-admin` | fetch raw admin kubeconfig (emergency use) |
| `pve-init` | generate PVE host secrets |
| `pve-bootstrap` | run Ansible against PVE host |
| `ssh-workload` | sign SSH cert for k3s nodes (`SSH_PRINCIPAL=$USER`, 8h) |
| `ssh-infra` | sign SSH cert for PVE host (`SSH_PRINCIPAL=$USER`, 1h) |

Key variables (all overridable):

| variable | default |
|----------|---------|
| `CLUSTER_NAME` | `homelab` |
| `K8S_USER` | `$USER` |
| `SSH_PRINCIPAL` | `$USER` |
| `SSH_PUBKEY` | `~/.ssh/id_rsa.pub` |
| `SOPS_AGE_KEY_FILE` | `~/.config/sops/age/keys.txt` |

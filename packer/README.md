# Packer golden images

Builds two Proxmox VM templates from Ubuntu 24.04 LTS:

- **ubuntu-k3s** (VM 9000) — k3s node base: kernel modules, sysctls, IPVS, storage clients. k3s itself installs at deploy time via cloud-init.
- **ubuntu-docker** (VM 9001) — Docker CE, containerd, buildx, compose.

## Build

```sh
cp secrets.pkrvars.hcl.example secrets.pkrvars.hcl
# edit secrets.pkrvars.hcl

make images        # both templates
make image-k3s     # k3s only
make image-docker  # docker only
```

A build fails if VM 9000 or 9001 already exists — remove the old template first.

## ISO

Set `proxmox_iso_file` to an ISO already on PVE storage (no download). Leave it empty to have Packer download and upload it, then set the printed volid for future builds. Build one template at a time while `proxmox_iso_file` is empty to avoid a download race.

## Proxmox API token

```sh
pveum role add PackerBuilder -privs \
  "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit \
   VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network \
   VM.Config.Options VM.Audit VM.PowerMgmt \
   Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit \
   SDN.Use Sys.Modify"
pveum user add packer@pve
pveum acl modify / -user packer@pve -role PackerBuilder
pveum user token add packer@pve packer-token --privsep 0
```

`proxmox_username` = `REDACTED_PROXMOX_USER`

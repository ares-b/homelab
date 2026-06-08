# Packer golden images

Builds two Proxmox VM templates from the same Ubuntu 24.04 LTS ISO:

- **ubuntu-k3s** (VM 9000): k3s node base. Kernel modules, sysctls, IPVS and
  storage clients, staged firewall ports. k3s itself is installed at deploy time.
- **ubuntu-docker** (VM 9001): Docker host. Docker CE, containerd, buildx and
  compose plugins.

Both share `scripts/base.sh`, `network.sh`, `security.sh`, `cleanup.sh` and the
`http/` autoinstall seed. Image-specific steps live in `scripts/docker.sh` and
`scripts/k3s-modules.sh`.

## Build

```sh
cp secrets.pkrvars.hcl.example secrets.pkrvars.hcl   # then edit

make images        # both templates
make image-k3s     # k3s only
make image-docker  # docker only
```

`deploy.sh` checks whether `proxmox_iso_file` already exists on PVE. If it does,
it attaches it and builds both in parallel; if not, it downloads the ISO once and
builds sequentially so the two builds do not race on the shared download.

To call packer directly:

```sh
packer init .
packer validate -var-file=secrets.pkrvars.hcl .
packer build -var-file=secrets.pkrvars.hcl .
packer build -only='ubuntu-k3s.proxmox-iso.ubuntu-k3s' -var-file=secrets.pkrvars.hcl .
```

A build fails if its VM id (9000/9001) already exists; remove the old template
first. Set `-var zero_free_space=true` for a smaller image at the cost of build
time.

## ISO handling

`proxmox_iso_file` attaches an ISO already on PVE storage, so nothing is
downloaded or uploaded and both images reuse the one copy. When it is empty,
Packer downloads `ubuntu_iso_url` into `downloaded_iso_path/` (shared by both
builds since they run from this directory), uploads it to PVE, and the log prints
the resulting volid. Set `proxmox_iso_file` to that volid afterwards.

While `proxmox_iso_file` is empty, build one image at a time
(`-only=...` or `-parallel-builds=1`): parallel builds would download to the same
`downloaded_iso_path` file and upload the same volid at once. Once
`proxmox_iso_file` is set there is no download, so `packer build .` runs both in
parallel safely.

`iso_download_pve` (PVE fetching the URL itself) is deliberately unused: the API
token lacks the download-url privilege behind PVE's SSRF guard.

## Proxmox API token

Use a dedicated role and token, not root:

```sh
pveum role add PackerBuilder -privs \
  "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit \
   VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network \
   VM.Config.Options VM.Audit VM.PowerMgmt \
   Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit \
   SDN.Use Sys.Modify"
pveum user add packer@pve --comment "Packer image builder"
pveum acl modify / -user packer@pve -role PackerBuilder
pveum user token add packer@pve packer-token --privsep 0
```

`proxmox_username` is then `REDACTED_PROXMOX_USER`.

## Applied at deploy time, not in the image

- k3s binary, node role (server vs agent), join token, TLS SANs
- hostname, static IP, SSH keys (injected via cloud-init)
- `ufw enable` (rules are staged but ufw is left off)

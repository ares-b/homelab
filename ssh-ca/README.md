# ssh-ca

SSH user certificate authorities for the homelab. Hosts trust a CA instead of
individual `authorized_keys`; access is granted by signing a short-lived
certificate, so there are no standing keys on the boxes and rotation happens
here, not on every node.

Two CAs, split by trust tier:

| dir         | signs for        | tier                                      |
|-------------|------------------|-------------------------------------------|
| `workload/` | k3s + docker VMs | cattle, reprovisionable, many principals  |
| `infra/`    | Proxmox host(s)  | hypervisor, owns every VM                  |

A single CA for everything would mean stealing its key from any workload VM
grants root on Proxmox. Separate roots keep that blast radius contained. Keep
the infra CA tighter: fewer principals, shorter TTLs.

Each tier holds `ca.pub` (public anchor, committed) and `ca.enc` (private key,
SOPS-encrypted, committed). The raw `ca` is never written except as a transient
temp file during signing.

## Generate the CAs

```sh
ssh-ca/init.sh
```

Idempotent: it skips a tier whose `ca.enc` already exists. The age recipient
comes from `pve-bootstrap/.sops.yaml`, or `AGE_RECIPIENT` for another setup.

## Full bootstrap order

```sh
ssh-ca/init.sh     # CAs (infra CA must exist before pve-bootstrap)
make pve-init      # host secrets (one time)
make all           # pve-bootstrap, then images, then k3s-apply
```

## Issue a cert and log in

```sh
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
ssh-ca/sign.sh workload ares 8h     # then: ssh ops@10.0.0.10
ssh-ca/sign.sh infra    ares 1h     # then: ssh ares@<pve-host>
```

`sign.sh` signs `~/.ssh/id_ed25519.pub` by default and writes the cert beside
it; OpenSSH presents it automatically. Pass a fourth argument for another key.

## How a host trusts the CA

Workload images bake the sshd config (`packer/scripts/security.sh`); the PVE
host gets it from the `pve_security` role:

```
TrustedUserCAKeys /etc/ssh/ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
```

The matching `ca.pub` and the per-user principals file are written at deploy
time (cloud-init on the VMs, the role on PVE). The Makefile injects the right
`ca.pub` so no module reads across directories. A login succeeds only with a
cert whose principal is listed for that user.

## Audit

sshd logs the cert Key ID (`<principal>@<timestamp>`) on every login, so even
on the shared `ops` account you can tell who it was. With auditd and sudo I/O
logging on the node, that is the full who-did-what trail.

## Rotation and revocation

- Remove a person: drop their principal from the host (a cloud-init or role
  change); their cert expires on its own anyway.
- Rotate a CA: delete that tier's `ca.enc`/`ca.pub`, rerun `ssh-ca/init.sh`,
  then redeploy so the new `ca.pub` lands on the hosts.
- A single break-glass key per host (`break_glass_keys`) covers a CA outage.

The PVE `ansible` account stays key-based: it is machine automation, not a
human, so the CA does not apply to it.

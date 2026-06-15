# ssh-ca

Two SSH certificate authorities split by trust tier:

| dir | signs for | notes |
|-----|-----------|-------|
| `workload/` | k3s + docker VMs | shorter blast radius |
| `infra/` | Proxmox host | owns every VM — keep tighter |

Each tier stores `ca.pub` (committed) and `ca.enc` (SOPS-encrypted private key, committed). The raw private key only exists as a transient temp file during signing.

## Generate CAs

```sh
ssh-ca/init.sh
```

Idempotent — skips tiers that already have `ca.enc`. Age recipient comes from `pve-bootstrap/.sops.yaml`.

## Sign a cert

```sh
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

make ssh-workload   # signs ~/.ssh/id_rsa.pub for k3s nodes, 8h
make ssh-infra      # signs for PVE host, 1h
```

Pass `SSH_PRINCIPAL` and `SSH_PUBKEY` to override defaults.

## Rotation

- **Revoke a person** — remove their principal from the host config; the cert expires on its own.
- **Rotate a CA** — delete `ca.enc`/`ca.pub`, rerun `ssh-ca/init.sh`, redeploy to push the new `ca.pub`.
- Each host has a `break_glass_keys` entry for CA outages.

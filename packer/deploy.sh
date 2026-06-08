#!/usr/bin/env bash
# Extra args are passed through to packer, e.g.
#   ./deploy.sh -only='ubuntu-k3s.*'
#   ./deploy.sh -var zero_free_space=true
set -euo pipefail
cd "$(dirname "$0")"

PVE_URL=${PKR_VAR_proxmox_url:-}
PVE_USER=${PKR_VAR_proxmox_username:-}
PVE_TOKEN=${PKR_VAR_proxmox_token:-}
PVE_NODE=${PKR_VAR_proxmox_node:-}
ISO_STORE=${PKR_VAR_proxmox_iso_storage_pool:-local}
ISO_FILE=${PKR_VAR_proxmox_iso_file:-}

iso_exists() {
  [[ -n $ISO_FILE ]] || return 1
  curl -sk -H "Authorization: PVEAPIToken=${PVE_USER}=${PVE_TOKEN}" \
    "${PVE_URL%/api2/json}/api2/json/nodes/${PVE_NODE}/storage/${ISO_STORE}/content?content=iso" \
    | grep -q "\"volid\":\"${ISO_FILE}\""
}

packer init . >/dev/null

if iso_exists; then
  echo "ISO present on PVE (${ISO_FILE}); building both in parallel."
  packer build "$@" .
else
  echo "ISO not on PVE; downloading once and building sequentially."
  packer build -parallel-builds=1 -var "proxmox_iso_file=" "$@" .
  echo "Bootstrap done. The ISO is now on PVE, so the next run builds in parallel."
fi

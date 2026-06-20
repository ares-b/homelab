#!/usr/bin/env bash
# Generate the workload and infra SSH user CAs.
#
# Refuses to overwrite an existing ca.enc, since regenerating a CA invalidates
# every certificate it has signed. To rotate, delete that tier's files first.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# age recipient to encrypt the private keys to. Defaults to the one declared in
# the repo's sops config; override with AGE_RECIPIENT for another environment.
sops_config="$here/../.sops.yaml"
recipient="${AGE_RECIPIENT:-$(grep -oE 'age1[0-9a-z]+' "$sops_config" 2>/dev/null | head -1)}"
if [[ -z "$recipient" ]]; then
  echo "no age recipient: set AGE_RECIPIENT or add one to $sops_config" >&2
  exit 1
fi

for tier in workload infra; do
  dir="$here/$tier"
  mkdir -p "$dir"
  if [[ -f "$dir/ca.enc" ]]; then
    echo "$tier: ca.enc exists, skipping"
    continue
  fi
  ssh-keygen -t ed25519 -f "$dir/ca" -C "homelab-ssh-${tier}-ca" -N '' >/dev/null
  sops --encrypt --age "$recipient" \
    --input-type binary --output-type binary "$dir/ca" > "$dir/ca.enc"
  shred -u "$dir/ca" 2>/dev/null || rm -f "$dir/ca"
  echo "$tier: wrote ca.pub and ca.enc"
done

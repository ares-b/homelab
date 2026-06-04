#!/usr/bin/env bash
# Issue a short-lived SSH user certificate signed by one of the CAs.
#
# Usage: sign.sh <workload|infra> <principal> [validity] [public_key]
#   validity defaults to 8h, public_key to ~/.ssh/id_ed25519.pub.
#
# The CA private key is decrypted from ca.enc in memory and never written to a
# persistent path. Needs the age key (SOPS_AGE_KEY_FILE or the default location).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tier="${1:?usage: sign.sh <workload|infra> <principal> [validity] [public_key]}"
principal="${2:?principal required}"
validity="${3:-8h}"
pubkey="${4:-$HOME/.ssh/id_ed25519.pub}"

ca_enc="$here/$tier/ca.enc"
[[ -f "$ca_enc" ]] || { echo "unknown tier '$tier': no $ca_enc" >&2; exit 1; }
[[ -f "$pubkey" ]] || { echo "public key not found: $pubkey" >&2; exit 1; }

ca_key="$(mktemp)"
trap 'shred -u "$ca_key" 2>/dev/null || rm -f "$ca_key"' EXIT
sops --decrypt --input-type binary --output-type binary "$ca_enc" > "$ca_key"
chmod 600 "$ca_key"

ssh-keygen -s "$ca_key" -I "${principal}@$(date +%Y-%m-%dT%H:%M)" \
  -n "$principal" -V "+${validity}" "$pubkey"

cert="${pubkey%.pub}-cert.pub"
echo "issued: $cert"
ssh-keygen -L -f "$cert" | grep -E "Valid|Principals"

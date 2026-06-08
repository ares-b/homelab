#!/usr/bin/env bash
set -euo pipefail

# Restrict cloud-init to the datasources Proxmox uses at clone time.
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/99-pve-datasource.cfg << 'EOF'
datasource_list: [NoCloud, ConfigDrive]
EOF

mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/99-fallback.conf << 'EOF'
[Resolve]
FallbackDNS=1.1.1.1 8.8.8.8 2606:4700:4700::1111
EOF

systemctl enable systemd-networkd
systemctl enable systemd-resolved

if dpkg -l network-manager 2>/dev/null | grep -q '^ii'; then
  systemctl disable NetworkManager || true
  systemctl mask NetworkManager || true
fi

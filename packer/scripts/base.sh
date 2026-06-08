#!/usr/bin/env bash
set -euo pipefail

# needrestart would restart ssh.service after the upgrade and drop Packer's
# session mid-build. List only; the image reboots on first clone boot anyway.
# Removed again in cleanup.sh so deployed nodes keep the default behaviour.
mkdir -p /etc/needrestart/conf.d
echo "\$nrconf{restart} = 'l';" > /etc/needrestart/conf.d/99-packer.conf

# Stop package postinst from restarting services. An openssh upgrade during
# full-upgrade restarts sshd and drops Packer's session; needrestart list-mode
# does not prevent that. cleanup.sh removes this.
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

# Wait for cloud-init and unattended-upgrades to release apt locks before
# proceeding; on first boot after autoinstall they run concurrently with Packer.
apt_wait() {
  local t=0
  while fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
        /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
    [ "$t" -ge 300 ] && { echo "apt lock held >300s, aborting" >&2; exit 1; }
    echo "waiting for apt lock (${t}s)"; sleep 3; t=$((t + 3))
  done
}

apt_wait
apt-get update
apt-get full-upgrade -y

apt-get install -y \
  curl \
  wget \
  ca-certificates \
  gnupg \
  qemu-guest-agent \
  cloud-init \
  cloud-utils \
  chrony \
  jq \
  unzip \
  git \
  htop \
  dnsutils

systemctl enable qemu-guest-agent
systemctl enable chrony

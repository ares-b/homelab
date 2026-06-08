#!/usr/bin/env bash
set -euo pipefail

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

rm -f /etc/needrestart/conf.d/99-packer.conf
rm -f /usr/sbin/policy-rc.d

truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

rm -f /root/.bash_history
find /home -maxdepth 2 -name '.bash_history' -delete
history -c || true
rm -rf /tmp/* /var/tmp/*

# /etc/cloud/cloud.cfg.d/ files are kept intentionally.
cloud-init clean --logs

# Written last so these directives never affect Packer's active session.
# Duplicated from 00-hardening.conf so hardening holds if CA config is absent.
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
MaxAuthTries 4
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 3
TCPKeepAlive yes
EOF
sshd -t

# Remove host keys after 'sshd -t' (which needs them present). cloud-init
# regenerates them on first clone boot.
rm -f /etc/ssh/ssh_host_*

if [[ "${ZERO_FREE_SPACE:-false}" == "true" ]]; then
  dd if=/dev/zero of=/zero.fill bs=1M status=progress 2>/dev/null || true
  rm -f /zero.fill
  sync
fi

echo "Cleanup complete."

# Last: drop the build user. This is the account Packer is connected as, so it
# ends the SSH session; the provisioner sets expect_disconnect for that reason.
# Everything above has already run, so a disconnect here loses nothing.
BUILD_USER="${BUILD_USER:-packer}"
rm -f "/etc/sudoers.d/${BUILD_USER}"
if id "${BUILD_USER}" &>/dev/null; then
  usermod -e 1 "${BUILD_USER}" || true
  userdel -r -f "${BUILD_USER}" 2>/dev/null || true
fi

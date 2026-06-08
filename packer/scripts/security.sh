#!/usr/bin/env bash
set -euo pipefail

apt-get install -y fail2ban

mkdir -p /etc/fail2ban/jail.d
cat > /etc/fail2ban/jail.d/sshd.conf << 'EOF'
[sshd]
enabled  = true
port     = ssh
maxretry = 5
bantime  = 3600
findtime = 600
EOF
systemctl enable fail2ban

apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'

echo "ufw base rules staged, not enabled"

apt-get install -y auditd audispd-plugins

cat > /etc/audit/rules.d/50-hardening.rules << 'EOF'
## Identity and privilege changes
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
## SSH / CA trust
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/ssh/sshd_config.d/ -p wa -k sshd
-w /etc/ssh/ca.pub -p wa -k sshd_ca
-w /etc/ssh/auth_principals/ -p wa -k sshd_ca
## sudo session log
-w /var/log/sudo.log -p wa -k actions
## every command run as root
-a always,exit -F arch=b64 -S execve -F euid=0 -k root-cmd
EOF
systemctl enable auditd

cat > /etc/sudoers.d/00-logging << 'EOF'
Defaults log_input, log_output
Defaults iolog_dir="/var/log/sudo-io/%{seq}"
Defaults logfile="/var/log/sudo.log"
EOF
chmod 0440 /etc/sudoers.d/00-logging
visudo -cf /etc/sudoers.d/00-logging

# ca.pub and auth_principals/<user> are written at first boot by cloud-init;
# the image stays generic across CA rotations. 00- sorts before 50-cloud-init.conf
# so sshd picks up these directives first (sshd uses the first value per keyword).
mkdir -p /etc/ssh/auth_principals
cat > /etc/ssh/sshd_config.d/00-hardening.conf << 'EOF'
TrustedUserCAKeys /etc/ssh/ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF

cat > /etc/cloud/cloud.cfg.d/99-no-keys-console.cfg << 'EOF'
ssh:
  emit_keys_to_console: false
no_ssh_fingerprints: true
EOF

echo "auditd, sudo I/O logging, and sshd CA trust staged in image"

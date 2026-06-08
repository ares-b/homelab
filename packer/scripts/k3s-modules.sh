#!/usr/bin/env bash
set -euo pipefail

apt-get install -y ipvsadm ipset conntrack open-iscsi nfs-common
systemctl enable open-iscsi

cat > /etc/modules-load.d/k3s.conf << 'EOF'
br_netfilter
overlay
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

cat > /etc/sysctl.d/99-k3s.conf << 'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding        = 1
vm.swappiness                       = 0
vm.overcommit_memory                = 1
vm.panic_on_oom                     = 0
kernel.panic                        = 10
kernel.panic_on_oops                = 1
net.core.somaxconn                  = 32768
net.ipv4.tcp_max_syn_backlog        = 8096
net.core.rmem_max                   = 134217728
net.core.wmem_max                   = 134217728
net.ipv4.tcp_keepalive_time         = 600
net.ipv4.tcp_keepalive_intvl        = 60
net.ipv4.tcp_keepalive_probes       = 9
# rp_filter=1 drops Flannel/WireGuard pod traffic that arrives on eth0 while
# routes point to the overlay interface, causing asymmetric path failures.
net.ipv4.conf.all.rp_filter         = 0
fs.inotify.max_user_instances       = 8192
fs.inotify.max_user_watches         = 524288
fs.file-max                         = 2097152
EOF

swapoff -a
sed -i '/^[^#].*\bswap\b/s/^/#/' /etc/fstab

mkdir -p /etc/rancher/k3s /var/lib/rancher/k3s/agent/images
: > /etc/rancher/k3s/config.yaml

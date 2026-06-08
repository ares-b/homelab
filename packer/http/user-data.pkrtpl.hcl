#cloud-config
autoinstall:
  version: 1

  refresh-installer:
    update: false

  locale: en_US.UTF-8
  keyboard:
    layout: us
  timezone: UTC

  network:
    network:
      version: 2
      ethernets:
        buildnic:
          match:
            name: "en*"
%{ if build_ip != "" }
          addresses:
            - ${build_ip}
          routes:
            - to: default
              via: ${build_gateway}
          nameservers:
            addresses:
              - ${build_nameserver}
%{ else }
          dhcp4: true
          dhcp6: false
%{ endif }

  identity:
    hostname: ubuntu-packer
    username: ${build_username}
    # SHA-512 crypt of the build password; subiquity creates the user with it so
    # Packer can SSH in without a chpasswd late-command.
    password: "${build_password_hash}"

  ssh:
    install-server: true
    allow-pw: true
    authorized-keys: []

  storage:
    layout:
      name: direct
    swap:
      size: 0

  packages:
    - qemu-guest-agent
    - openssh-server

  late-commands:
    - echo "${build_username} ALL=(ALL) NOPASSWD:ALL" > /target/etc/sudoers.d/${build_username}
    - chmod 0440 /target/etc/sudoers.d/${build_username}
    - curtin in-target --target=/target -- systemctl enable qemu-guest-agent
    # cloud-init stays enabled: on 24.04 subiquity defers netplan rendering to
    # cloud-init's first boot, so disabling it leaves the NIC with no IP.

  shutdown: reboot

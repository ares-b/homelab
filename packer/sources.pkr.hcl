packer {
  required_version = ">= 1.10.0"
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

locals {
  user_data = templatefile("${path.root}/http/user-data.pkrtpl.hcl", {
    build_username      = var.ssh_build_username
    build_password_hash = var.ssh_build_password_hash
    build_ip            = var.build_ip
    build_gateway       = var.build_gateway
    build_nameserver    = var.build_nameserver
  })

  # The 24.04 ISO boots GRUB. <down><up> halts the menu countdown, c opens the
  # GRUB console, then the kernel line is typed so it does not depend on the menu
  # layout. ds=nocloud reads the autoinstall seed from the CIDATA CD-ROM.
  boot_command = [
    "<down><up><wait>",
    "c<wait>",
    "linux /casper/vmlinuz autoinstall ds=nocloud ---<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
}

source "proxmox-iso" "ubuntu-k3s" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  node                     = var.proxmox_node
  task_timeout             = "10m"

  vm_id                = var.k3s_vm_id
  vm_name              = "ubuntu-k3s-template"
  template_description = "Ubuntu 24.04 LTS k3s node image"
  # Disk first so the post-install reboot boots the installed system. The disk
  # is empty during install, so the BIOS falls through to the ISO (ide2).
  boot = "order=scsi0;ide2;net0"

  # Attach an ISO already on PVE storage (proxmox_iso_file): no download, no
  # upload, shared across images. Empty falls back to downloading ubuntu_iso_url
  # and uploading it once. iso_download_pve is not used: the API token lacks the
  # download-url privilege behind PVE's SSRF guard.
  boot_iso {
    iso_file         = var.proxmox_iso_file != "" ? var.proxmox_iso_file : null
    iso_url          = var.proxmox_iso_file == "" ? var.ubuntu_iso_url : null
    iso_checksum     = var.proxmox_iso_file == "" ? var.ubuntu_iso_checksum : null
    iso_storage_pool = var.proxmox_iso_storage_pool
    unmount          = true
  }

  cores           = 2
  memory          = 2048
  os              = "l26"
  scsi_controller = "virtio-scsi-pci"

  disks {
    type         = "scsi"
    disk_size    = "20G"
    storage_pool = var.proxmox_storage_pool
    format       = "raw"
    ssd          = true
    discard      = true
  }

  network_adapters {
    model  = "virtio"
    bridge = var.proxmox_bridge
  }

  # Deliver the autoinstall seed on a CIDATA CD-ROM (cloud-init NoCloud) so the
  # build needs no network path back to the Packer host (works behind NAT/WSL2).
  additional_iso_files {
    cd_label         = "cidata"
    iso_storage_pool = var.proxmox_iso_storage_pool
    unmount          = true
    cd_content = {
      "user-data" = local.user_data
      "meta-data" = "instance-id: ubuntu-k3s-packer\nlocal-hostname: ubuntu-packer\n"
    }
  }

  qemu_agent              = true
  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_storage_pool

  boot_wait         = "5s"
  boot_key_interval = "100ms"
  boot_command      = local.boot_command

  communicator           = "ssh"
  ssh_username           = var.ssh_build_username
  ssh_password           = var.ssh_build_password
  ssh_timeout            = "60m"
  ssh_handshake_attempts = 50
}

source "proxmox-iso" "ubuntu-docker" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  node                     = var.proxmox_node
  task_timeout             = "10m"

  vm_id                = var.docker_vm_id
  vm_name              = "ubuntu-docker-template"
  template_description = "Ubuntu 24.04 LTS docker host image"
  boot                 = "order=scsi0;ide2;net0"

  boot_iso {
    iso_file         = var.proxmox_iso_file != "" ? var.proxmox_iso_file : null
    iso_url          = var.proxmox_iso_file == "" ? var.ubuntu_iso_url : null
    iso_checksum     = var.proxmox_iso_file == "" ? var.ubuntu_iso_checksum : null
    iso_storage_pool = var.proxmox_iso_storage_pool
    unmount          = true
  }

  cores           = 2
  memory          = 2048
  os              = "l26"
  scsi_controller = "virtio-scsi-pci"

  disks {
    type         = "scsi"
    disk_size    = "20G"
    storage_pool = var.proxmox_storage_pool
    format       = "raw"
    ssd          = true
    discard      = true
  }

  network_adapters {
    model  = "virtio"
    bridge = var.proxmox_bridge
  }

  additional_iso_files {
    cd_label         = "cidata"
    iso_storage_pool = var.proxmox_iso_storage_pool
    unmount          = true
    cd_content = {
      "user-data" = local.user_data
      "meta-data" = "instance-id: ubuntu-docker-packer\nlocal-hostname: ubuntu-packer\n"
    }
  }

  qemu_agent              = true
  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_storage_pool

  boot_wait         = "5s"
  boot_key_interval = "100ms"
  boot_command      = local.boot_command

  communicator           = "ssh"
  ssh_username           = var.ssh_build_username
  ssh_password           = var.ssh_build_password
  ssh_timeout            = "60m"
  ssh_handshake_attempts = 50
}

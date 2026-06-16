locals {
  template = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
}

resource "proxmox_virtual_environment_container" "edge_gateway" {
  node_name = var.proxmox.node
  vm_id     = var.lxc.vmid
  tags      = ["edge-access"]

  unprivileged = false

  initialization {
    hostname = var.lxc.hostname

    ip_config {
      ipv4 {
        address = var.lxc.ip
        gateway = var.lxc.gateway
      }
    }

    user_account {
      keys = [var.lxc.ssh_public_key]
    }
  }

  cpu {
    cores = var.lxc.cpus
  }

  memory {
    dedicated = var.lxc.memory
    swap      = 0
  }

  disk {
    datastore_id = var.lxc.storage
    size         = var.lxc.disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.lxc.bridge
  }

  operating_system {
    template_file_id = local.template
    type             = "debian"
  }

  start_on_boot = true
  started       = true
}

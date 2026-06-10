locals {
  # Resolve pve_node for every node, falling back to default_pve_node when not set.
  resolved_nodes = {
    for name, n in var.nodes : name => merge(n, {
      pve_node = coalesce(n.pve_node, var.default_pve_node)
    })
  }

  # The single server's address is the join target for every agent.
  server_ip = split("/", one([for n in var.nodes : n.ip if n.role == "server"]))[0]

  install_command = {
    for name, n in var.nodes : name => (
      n.role == "server"
      ? "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} K3S_TOKEN=${random_password.k3s_token.result} sh -s - server --tls-san ${local.server_ip} --write-kubeconfig-mode 0644 --node-name ${name}"
      : "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} K3S_URL=https://${local.server_ip}:6443 K3S_TOKEN=${random_password.k3s_token.result} sh -s - agent --node-name ${name}"
    )
  }
}

# Fail fast if any node references a PVE node not declared in pve_node_addresses.
resource "terraform_data" "validate_node_placement" {
  lifecycle {
    precondition {
      condition = alltrue([
        for n in local.resolved_nodes : contains(keys(var.pve_node_addresses), n.pve_node)
      ])
      error_message = "Each node's pve_node must be a key in pve_node_addresses."
    }
  }
}

# Shared join token. Agents retry until the server is up, so node boot order
# does not matter.
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

resource "proxmox_virtual_environment_file" "user_data" {
  for_each = local.resolved_nodes

  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = each.value.pve_node

  source_raw {
    file_name = "${each.key}-user-data.yaml"
    data = templatefile("${path.module}/templates/k3s-node.cloud-init.yaml.tftpl", {
      hostname          = each.key
      role              = each.value.role
      ssh_ca_public_key = var.ssh_ca_public_key
      principals        = var.ssh_principals
      break_glass_keys  = var.break_glass_keys
      install_command   = local.install_command[each.key]
    })
  }
}

resource "proxmox_virtual_environment_vm" "k3s" {
  for_each = local.resolved_nodes

  name      = each.key
  node_name = each.value.pve_node
  tags      = ["k3s", each.value.role]

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.root_disk_gb
  }

  dynamic "disk" {
    for_each = each.value.data_disk_gb > 0 ? [each.value.data_disk_gb] : []
    content {
      datastore_id = var.data_datastore_id
      interface    = "scsi1"
      size         = disk.value
    }
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data[each.key].id
  }

  on_boot = true

  lifecycle {
    # The template's cloud-init drive details change on clone; ignore churn.
    ignore_changes = [clone]
  }
}

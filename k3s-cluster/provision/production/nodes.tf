locals {
  resolved_nodes = {
    for name, n in var.nodes : name => merge(n, {
      pve_node = coalesce(n.pve_node, var.default_pve_node)
    })
  }

  server_ip = split("/", one([for n in var.nodes : n.ip if n.role == "server"]))[0]

  install_command = {
    for name, n in var.nodes : name => (
      n.role == "server"
      ? "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} K3S_TOKEN=${random_password.k3s_token.result} sh -s - server --tls-san ${local.server_ip} --write-kubeconfig-mode 0644 --node-name ${name}"
      : "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} K3S_URL=https://${local.server_ip}:6443 K3S_TOKEN=${random_password.k3s_token.result} sh -s - agent --node-name ${name}"
    )
  }

  disk_device_letters = ["b", "c", "d", "e", "f"]

  ansible_dir = abspath("${path.module}/../ansible")
  inventory   = "${local.ansible_dir}/inventory.ini"
  vm_ids      = jsonencode([for name, vm in proxmox_virtual_environment_vm.k3s : vm.id])
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
    for_each = { for i, d in each.value.data_disks : i => d }
    content {
      datastore_id = disk.value.datastore_id
      interface    = "scsi${disk.key + 1}"
      size         = disk.value.size_gb
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

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    nodes = local.resolved_nodes
  })
}

resource "local_file" "host_vars" {
  for_each = local.resolved_nodes

  filename = "${path.module}/../ansible/host_vars/${each.key}.yml"
  content = templatefile("${path.module}/templates/host-vars.yml.tftpl", {
    data_disks = [
      for i, disk in each.value.data_disks : merge(disk, {
        device = "/dev/sd${local.disk_device_letters[i]}"
        label  = "k3s-${disk.type}"
        mount  = "/var/lib/k3s-${disk.type}"
        fs     = "ext4"
      })
    ]
  })
}

resource "terraform_data" "wait_for_nodes" {
  triggers_replace = { vm_ids = local.vm_ids }

  depends_on = [
    proxmox_virtual_environment_vm.k3s,
    local_file.ansible_inventory,
    local_file.host_vars,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      ${join("\n      ", [for name, vm in proxmox_virtual_environment_vm.k3s : "ssh-keygen -R ${split("/", local.resolved_nodes[name].ip)[0]} 2>/dev/null || true"])}
      echo "Waiting for k3s nodes to be reachable..."
      until ansible k3s -i '${local.inventory}' -m ping --timeout=5 >/dev/null 2>&1; do
        sleep 15
      done
    EOT
  }
}

resource "terraform_data" "disk_setup" {
  triggers_replace = { vm_ids = local.vm_ids }

  depends_on = [terraform_data.wait_for_nodes]

  provisioner "local-exec" {
    command = "ansible-playbook -i '${local.inventory}' '${local.ansible_dir}/disk-setup.yml'"
  }
}

resource "terraform_data" "k8s_nodes" {
  triggers_replace = { vm_ids = local.vm_ids }

  depends_on = [terraform_data.disk_setup]

  provisioner "local-exec" {
    command = "ansible-playbook -i '${local.inventory}' '${local.ansible_dir}/k8s-nodes.yml'"
  }
}

resource "terraform_data" "k8s_users" {
  triggers_replace = { vm_ids = local.vm_ids, k8s_users = jsonencode(var.k8s_users) }

  depends_on = [terraform_data.k8s_nodes]

  provisioner "local-exec" {
    command = "ansible-playbook -i '${local.inventory}' '${local.ansible_dir}/k8s-users.yml' -e '{\"k8s_users\":${jsonencode(var.k8s_users)}}'"
  }
}

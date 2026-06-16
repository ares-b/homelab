output "lxc_ip" {
  description = "LXC container IP (without prefix). Matches lxc.ip in config.sops.yaml."
  value       = split("/", var.lxc.ip)[0]
  sensitive   = true
}

output "lxc_vmid" {
  description = "LXC container VM ID."
  value       = proxmox_virtual_environment_container.edge_gateway.vm_id
  sensitive   = true
}

variable "proxmox" {
  type = object({
    endpoint     = string
    api_token    = string
    insecure     = bool
    node         = string
  })
  sensitive   = true
  description = "Proxmox connection config. Passed as TF_VAR_proxmox JSON from config.sops.yaml."
}

variable "lxc" {
  type = object({
    vmid                    = number
    hostname                = string
    cpus                    = number
    memory                  = number
    disk_size               = number
    storage                 = string
    bridge                  = string
    ip                      = string
    gateway                 = string
    ssh_public_key          = string
    ansible_ssh_private_key = string
  })
  sensitive   = true
  description = "LXC container config. ip must be CIDR (e.g. 10.0.0.200/24)."

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+/\\d+$", var.lxc.ip))
    error_message = "lxc.ip must be CIDR notation, e.g. 10.0.0.200/24."
  }
}

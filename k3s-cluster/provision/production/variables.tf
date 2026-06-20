variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint, e.g. https://REDACTED_PVE_IP:8006/"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "API token in the form 'user@realm!tokenid=secret'."
}

variable "proxmox_insecure" {
  type        = bool
  default     = false
  description = "Skip TLS verification. Set true only for self-signed PVE certificates."
}

variable "default_pve_node" {
  type        = string
  description = "Default PVE node name for VMs that do not specify pve_node."
}

variable "pve_node_addresses" {
  type        = map(string)
  description = "Map of PVE node name to management IP for SSH snippet uploads. Node names are not DNS-resolvable; the provider needs explicit addresses."

  validation {
    condition     = length(var.pve_node_addresses) > 0
    error_message = "At least one PVE node address is required."
  }
}

variable "pve_ssh_username" {
  type        = string
  default     = "ansible"
  description = "SSH user on every PVE node for snippet uploads. Must have sudo."
}

variable "pve_ssh_private_key" {
  type        = string
  description = "PEM content of the private key for pve_ssh_username."
}

variable "template_vm_id" {
  type        = number
  default     = 9000
  description = "VM ID of the Packer-built ubuntu-k3s template to clone."
}

variable "datastore_id" {
  type        = string
  default     = "local-lvm"
  description = "Datastore for VM root disks and the cloud-init drive."
}

variable "snippet_datastore_id" {
  type        = string
  default     = "sda-data"
  description = "Datastore holding cloud-init snippets. Must allow the 'snippets' content type."
}

variable "network_bridge" {
  type        = string
  default     = "vmbr10"
  description = "Bridge for the cluster network."
}

variable "gateway" {
  type        = string
  default     = "10.0.0.1"
  description = "Default gateway for the nodes."
}

variable "nameserver" {
  type        = string
  default     = "1.1.1.1"
  description = "DNS server for the nodes."
}

variable "ssh_ca_public_key" {
  type        = string
  description = "Workload SSH CA public key (trust anchor) written to every node. Injected by the Makefile from ssh-ca/workload/ca.pub; no default so it can't silently drift."

  validation {
    condition     = can(regex("^ssh-(ed25519|rsa) ", var.ssh_ca_public_key))
    error_message = "ssh_ca_public_key must be an OpenSSH public key (run via 'make k3s-apply')."
  }
}

variable "ssh_principals" {
  type        = list(string)
  default     = ["ares"]
  description = "Principals allowed to log in as 'ops' via an SSH CA certificate."
}

variable "break_glass_keys" {
  type        = list(string)
  description = "Standing emergency SSH keys on the 'ops' user, used when the SSH CA is unreachable. Keep this short; prefer a dedicated SOPS-stored key."
}

variable "root_disk_gb" {
  type        = number
  default     = 40
  description = "Root disk size per node. Must be >= the template disk (20G)."
}

variable "k3s_version" {
  type        = string
  default     = "v1.35.5+k3s1"
  description = "Pinned k3s version (INSTALL_K3S_VERSION) for reproducible installs."
}

variable "nodes" {
  type = map(object({
    role       = string
    pve_node   = optional(string)
    cores      = number
    memory     = number
    ip         = string
    data_disks = optional(list(object({
      size_gb      = number
      type         = string
      datastore_id = string
    })), [])
  }))
  description = "Cluster nodes. Exactly one must have role 'server'. ip is CIDR; memory is MB. pve_node defaults to default_pve_node when omitted."
  default = {
    k3s-cp-01 = {
      role   = "server"
      cores  = 2
      memory = 4096
      ip     = "10.0.0.10/24"
      data_disks = [
        { size_gb = 300, type = "nvme", datastore_id = "local-lvm" },
        { size_gb = 500, type = "ssd",  datastore_id = "sda-data"  },
      ]
    }
    k3s-worker-01 = {
      role   = "agent"
      cores  = 2
      memory = 4096
      ip     = "10.0.0.11/24"
      data_disks = [
        { size_gb = 300, type = "nvme", datastore_id = "local-lvm" },
        { size_gb = 500, type = "ssd",  datastore_id = "sda-data"  },
      ]
    }
    k3s-worker-02 = {
      role   = "agent"
      cores  = 2
      memory = 4096
      ip     = "10.0.0.12/24"
      data_disks = [
        { size_gb = 300, type = "nvme", datastore_id = "local-lvm" },
        { size_gb = 500, type = "ssd",  datastore_id = "sda-data"  },
      ]
    }
  }

  validation {
    condition     = alltrue([for n in var.nodes : contains(["server", "agent"], n.role)])
    error_message = "Each node role must be 'server' or 'agent'."
  }

  validation {
    condition     = length([for n in var.nodes : n if n.role == "server"]) == 1
    error_message = "Exactly one node must have role 'server'."
  }
}

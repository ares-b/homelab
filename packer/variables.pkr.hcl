variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL, e.g. https://REDACTED_PVE_IP:8006/api2/json"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API token id, e.g. REDACTED_PROXMOX_USER"
}

variable "proxmox_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build on, e.g. pve01"
}

# VM ids are unique across the whole cluster. Override per node when building the
# same template on more than one node, e.g. 9000/9001 on pve01, 9010/9011 on pve02.
variable "k3s_vm_id" {
  type        = number
  default     = 9000
  description = "VM id for the ubuntu-k3s template"
}

variable "docker_vm_id" {
  type        = number
  default     = 9001
  description = "VM id for the ubuntu-docker template"
}

variable "proxmox_insecure_skip_tls_verify" {
  type        = bool
  default     = false
  description = "Skip API TLS verification. Set true only for self-signed certs."
}

variable "proxmox_storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool for the VM disk and cloud-init drive"
}

variable "proxmox_iso_storage_pool" {
  type        = string
  default     = "local"
  description = "Storage pool for ISO uploads (needs the iso content type)"
}

variable "proxmox_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Bridge for the build VM. Clones inherit it unless the deploy layer overrides it."
}

variable "build_ip" {
  type        = string
  default     = ""
  description = "Static CIDR for the build VM, e.g. 10.0.0.9/24. Empty uses DHCP. Must be reachable from the host running Packer."
}

variable "build_gateway" {
  type        = string
  default     = ""
  description = "Default gateway for the build VM when build_ip is set"
}

variable "build_nameserver" {
  type        = string
  default     = "1.1.1.1"
  description = "DNS server for the build VM when build_ip is set"
}

variable "proxmox_iso_file" {
  type        = string
  default     = ""
  description = "Existing ISO volid on PVE, e.g. local:iso/<sha1>.iso. When set, the ISO is attached directly with no download or upload. Empty falls back to downloading ubuntu_iso_url and uploading it once."
}

variable "ubuntu_iso_url" {
  type        = string
  default     = "https://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-live-server-amd64.iso"
  description = "Ubuntu ISO URL, used only when proxmox_iso_file is empty"
}

variable "ubuntu_iso_checksum" {
  type        = string
  default     = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
  description = "ISO checksum (sha256:<hash>), used only when proxmox_iso_file is empty"
}

variable "ssh_build_username" {
  type        = string
  default     = "packer"
  description = "Temporary build user, removed in cleanup.sh"
}

variable "ssh_build_password" {
  type      = string
  sensitive = true
}

variable "ssh_build_password_hash" {
  type        = string
  sensitive   = true
  description = "SHA-512 crypt of ssh_build_password (openssl passwd -6)"
}

variable "zero_free_space" {
  type        = bool
  default     = false
  description = "Zero free space before templating (smaller image, slower build)"
}

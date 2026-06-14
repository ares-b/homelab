provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # SSH is only used to upload the cloud-init snippets to the snippet datastore.
  # The user needs sudo on the node; the bootstrap 'ansible' user fits.
  ssh {
    username    = var.pve_ssh_username
    private_key = var.pve_ssh_private_key

    # The provider resolves node names to SSH addresses via the API; PVE node
    # names are not DNS-resolvable, so each is mapped to its management IP.
    dynamic "node" {
      for_each = var.pve_node_addresses
      content {
        name    = node.key
        address = node.value
      }
    }
  }
}

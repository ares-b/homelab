terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

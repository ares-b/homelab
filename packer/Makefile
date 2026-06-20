ROOT        := $(CURDIR)/..
CONFIG_SOPS := $(ROOT)/config.sops.yaml
SOPS_EXEC   := python3 $(ROOT)/scripts/sops-exec.py
PACKER_ARGS ?=

.PHONY: help images image-k3s image-docker

help:
	@echo "images        build all Packer templates"
	@echo "image-k3s     build only the k3s template"
	@echo "image-docker  build only the docker template"

images:
	sops exec-file $(CONFIG_SOPS) '$(SOPS_EXEC) {} PKR_VAR_ packer ./deploy.sh $(PACKER_ARGS)'

image-k3s:
	sops exec-file $(CONFIG_SOPS) '$(SOPS_EXEC) {} PKR_VAR_ packer ./deploy.sh -only="ubuntu-k3s.proxmox-iso.ubuntu-k3s" $(PACKER_ARGS)'

image-docker:
	sops exec-file $(CONFIG_SOPS) '$(SOPS_EXEC) {} PKR_VAR_ packer ./deploy.sh -only="ubuntu-docker.proxmox-iso.ubuntu-docker" $(PACKER_ARGS)'

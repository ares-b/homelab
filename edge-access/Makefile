export PATH := $(HOME)/.local/bin:$(PATH)
ANSIBLE     ?= ansible-playbook
ANSIBLE_DIR := ansible
INVENTORY   := inventory/hosts.yml
TF_DIR      := terraform
CONFIG      := config.sops.yaml
SOPS_EXEC   := python3 $(CURDIR)/../scripts/sops-exec.py

.PHONY: setup tf-apply tf-destroy deploy vps lxc

setup:
	ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml -p $(ANSIBLE_DIR)/collections
	cd $(ANSIBLE_DIR) && $(ANSIBLE) init.yml

tf-apply: _tf-init
	sops exec-file $(CONFIG) '$(SOPS_EXEC) {} TF_VAR_ sh -c "stty sane; terraform -chdir=$(TF_DIR) apply"'

tf-destroy: _tf-init
	sops exec-file $(CONFIG) '$(SOPS_EXEC) {} TF_VAR_ sh -c "stty sane; terraform -chdir=$(TF_DIR) destroy"'

deploy:
	sops exec-file $(CONFIG) 'cd $(ANSIBLE_DIR) && $(ANSIBLE) -i $(INVENTORY) -e @{} site.yml'

vps:
	sops exec-file $(CONFIG) 'cd $(ANSIBLE_DIR) && $(ANSIBLE) -i $(INVENTORY) -e @{} site.yml --limit vps,localhost'

lxc:
	sops exec-file $(CONFIG) 'cd $(ANSIBLE_DIR) && $(ANSIBLE) -i $(INVENTORY) -e @{} site.yml --limit lxc_gateways,proxmox_nodes,localhost'

_tf-init:
	terraform -chdir=$(TF_DIR) init -input=false

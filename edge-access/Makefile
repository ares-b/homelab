export PATH := $(HOME)/.local/bin:$(PATH)
ANSIBLE      ?= ansible-playbook
ANSIBLE_DIR  := ansible
INVENTORY    := inventory/hosts.yml
TF_DIR       := terraform
CONFIG_SOPS  := $(CURDIR)/../config.sops.yaml
SOPS_EXEC    := python3 $(CURDIR)/../scripts/sops-exec.py
SOPS_ANSIBLE := python3 $(CURDIR)/../scripts/sops-ansible.py

.PHONY: setup tf-apply tf-destroy deploy vps lxc

setup:
	ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml -p $(ANSIBLE_DIR)/collections
	cd $(ANSIBLE_DIR) && $(ANSIBLE) init.yml

tf-apply: _tf-init
	sops exec-file $(CONFIG_SOPS) \
		'$(SOPS_EXEC) {} TF_VAR_ edge_access sh -c "stty sane; terraform -chdir=$(TF_DIR) apply"'

tf-destroy: _tf-init
	sops exec-file $(CONFIG_SOPS) \
		'$(SOPS_EXEC) {} TF_VAR_ edge_access sh -c "stty sane; terraform -chdir=$(TF_DIR) destroy"'

deploy:
	sops exec-file $(CONFIG_SOPS) \
		'$(SOPS_ANSIBLE) {} edge_access \
		sh -c "cd $(CURDIR)/$(ANSIBLE_DIR) && $(ANSIBLE) -i $(INVENTORY) site.yml -e @{section_vars}"'

vps:
	sops exec-file $(CONFIG_SOPS) \
		'$(SOPS_ANSIBLE) {} edge_access \
		sh -c "cd $(CURDIR)/$(ANSIBLE_DIR) && $(ANSIBLE) -i $(INVENTORY) site.yml -e @{section_vars} --limit vps,localhost"'

lxc:
	sops exec-file $(CONFIG_SOPS) \
		'$(SOPS_ANSIBLE) {} edge_access \
		sh -c "cd $(CURDIR)/$(ANSIBLE_DIR) && $(ANSIBLE) -i $(INVENTORY) site.yml -e @{section_vars} --limit lxc_gateways,proxmox_nodes,localhost"'

_tf-init:
	terraform -chdir=$(TF_DIR) init -input=false

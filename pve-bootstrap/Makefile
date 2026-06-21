ROOT          := $(CURDIR)/..
CONFIG_SOPS   := $(ROOT)/config.sops.yaml
SOPS_ANSIBLE  := python3 $(ROOT)/scripts/sops-ansible.py
INFRA_CA_FILE := $(ROOT)/ssh-ca/infra/ca.pub
INFRA_CA       = $(shell cat $(INFRA_CA_FILE) 2>/dev/null)
ANSIBLE       ?= ansible-playbook

export ANSIBLE_CONFIG := $(ROOT)/ansible.cfg

.PHONY: help setup init bootstrap

help:
	@echo "setup      install ansible collections"
	@echo "init       generate host secrets into config.sops.yaml (pve_bootstrap)"
	@echo "bootstrap  configure the PVE host (site.yml)"

setup:
	ansible-galaxy collection install -r requirements.yml -p collections

init:
	$(ANSIBLE) init.yml

$(INFRA_CA_FILE):
	@echo "missing $@; generate the CA first (see ssh-ca/README.md)" >&2; exit 1

bootstrap: | $(INFRA_CA_FILE)
	ANSIBLE_EV_pve_security_ssh_ca_public_key='$(INFRA_CA)' \
	sops exec-file $(CONFIG_SOPS) \
		'$(SOPS_ANSIBLE) {} pve_bootstrap \
		$(ANSIBLE) -i inventory site.yml -e @{section_vars}'

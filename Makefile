# ssh_ca_public_key has no default — injected from ssh-ca/*/ca.pub so it can't silently drift.
WORKLOAD_CA_FILE  := ssh-ca/workload/ca.pub
INFRA_CA_FILE     := ssh-ca/infra/ca.pub
TF_DIR            := k3s-cluster/provision/production
ANSIBLE           ?= ansible-playbook
SOPS_EXEC         := python3 $(CURDIR)/scripts/sops-exec.py
SSH_PRINCIPAL     ?= $(USER)
SSH_PUBKEY        ?= $(HOME)/.ssh/id_rsa.pub
SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt

WORKLOAD_CA = $(shell cat $(WORKLOAD_CA_FILE) 2>/dev/null)
INFRA_CA    = $(shell cat $(INFRA_CA_FILE) 2>/dev/null)

PACKER_ARGS ?=

ANSIBLE_DIR := k3s-cluster/provision/ansible

.PHONY: help all images image-k3s image-docker k3s-plan k3s-apply k3s-destroy k3s-disk-setup pve-init pve-bootstrap ssh-workload ssh-infra

help:
	@echo "all              pve-bootstrap, then images, then k3s-apply"
	@echo "images           build all Packer templates"
	@echo "image-k3s        build only the k3s template"
	@echo "image-docker     build only the docker template"
	@echo "k3s-plan         terraform plan"
	@echo "k3s-apply        terraform apply"
	@echo "k3s-destroy      terraform destroy"
	@echo "k3s-disk-setup   format and mount data disks on k3s nodes"
	@echo "pve-init         generate host secrets (ansible init.yml)"
	@echo "pve-bootstrap    configure the host (ansible site.yml)"
	@echo "ssh-workload     sign SSH cert for k3s nodes  (SSH_PRINCIPAL=$(USER))"
	@echo "ssh-infra        sign SSH cert for PVE host   (SSH_PRINCIPAL=$(USER))"

all: pve-bootstrap images k3s-apply

$(WORKLOAD_CA_FILE) $(INFRA_CA_FILE):
	@echo "missing $@; generate the CA first (see ssh-ca/README.md)" >&2; exit 1

images:
	cd packer && sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} PKR_VAR_ ./deploy.sh $(PACKER_ARGS)'

image-k3s:
	cd packer && sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} PKR_VAR_ ./deploy.sh -only="ubuntu-k3s.proxmox-iso.ubuntu-k3s" $(PACKER_ARGS)'

image-docker:
	cd packer && sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} PKR_VAR_ ./deploy.sh -only="ubuntu-docker.proxmox-iso.ubuntu-docker" $(PACKER_ARGS)'

k3s-plan k3s-apply k3s-destroy: | $(WORKLOAD_CA_FILE)

k3s-plan:
	cd $(TF_DIR) && TF_VAR_ssh_ca_public_key='$(WORKLOAD_CA)' \
		sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} TF_VAR_ terraform plan'

k3s-apply:
	cd $(TF_DIR) && TF_VAR_ssh_ca_public_key='$(WORKLOAD_CA)' \
		sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} TF_VAR_ terraform apply'

k3s-destroy:
	cd $(TF_DIR) && TF_VAR_ssh_ca_public_key='$(WORKLOAD_CA)' \
		sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} TF_VAR_ terraform destroy'

k3s-disk-setup:
	cd $(ANSIBLE_DIR) && $(ANSIBLE) -i inventory.ini disk-setup.yml

ssh-workload:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) ssh-ca/sign.sh workload $(SSH_PRINCIPAL) 8h $(SSH_PUBKEY)

ssh-infra:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) ssh-ca/sign.sh infra $(SSH_PRINCIPAL) 1h $(SSH_PUBKEY)

pve-init:
	cd pve-bootstrap && $(ANSIBLE) init.yml

pve-bootstrap: | $(INFRA_CA_FILE)
	cd pve-bootstrap && $(ANSIBLE) site.yml \
		-e '{"pve_security_ssh_ca_public_key": "$(INFRA_CA)"}'

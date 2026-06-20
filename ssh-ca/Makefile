SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt
SSH_PRINCIPAL     ?= $(USER)
SSH_PUBKEY        ?= $(HOME)/.ssh/id_rsa.pub

.PHONY: help init workload infra

help:
	@echo "init      generate workload + infra CAs (refuses to overwrite)"
	@echo "workload  sign an 8h cert for k3s nodes  (SSH_PRINCIPAL=$(USER))"
	@echo "infra     sign a 1h cert for the PVE host (SSH_PRINCIPAL=$(USER))"

init:
	./init.sh

workload:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) ./sign.sh workload $(SSH_PRINCIPAL) 8h $(SSH_PUBKEY)

infra:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) ./sign.sh infra $(SSH_PRINCIPAL) 1h $(SSH_PUBKEY)

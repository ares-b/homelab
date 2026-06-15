WORKLOAD_CA_FILE  := ssh-ca/workload/ca.pub
INFRA_CA_FILE     := ssh-ca/infra/ca.pub
TF_DIR            := k3s-cluster/provision/production
ANSIBLE           ?= ansible-playbook
SOPS_EXEC         := python3 $(CURDIR)/scripts/sops-exec.py
SSH_PRINCIPAL     ?= $(USER)
SSH_PUBKEY        ?= $(HOME)/.ssh/id_rsa.pub
SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt
CLUSTER_NAME      ?= homelab
KUBECONFIG_ADMIN  ?= $(HOME)/.kube/$(CLUSTER_NAME)-admin.yaml
K8S_USER          ?= $(USER)

WORKLOAD_CA = $(shell cat $(WORKLOAD_CA_FILE) 2>/dev/null)
INFRA_CA    = $(shell cat $(INFRA_CA_FILE) 2>/dev/null)

PACKER_ARGS ?=

.PHONY: help images image-k3s image-docker k3s-plan k3s-apply k3s-destroy \
        k3s-disk-setup k3s-kubeconfig k3s-kubeconfig-admin pve-init pve-bootstrap ssh-workload ssh-infra

help:
	@echo "images               build all Packer templates"
	@echo "image-k3s            build only the k3s template"
	@echo "image-docker         build only the docker template"
	@echo "k3s-disk-setup       convert data disks to LVM (run after scaling down workloads)"
	@echo "k3s-plan             terraform plan"
	@echo "k3s-apply            terraform apply (provisions VMs, disks, k8s users, kubeconfig)"
	@echo "k3s-destroy          terraform destroy"
	@echo "k3s-kubeconfig       write kubeconfig for K8S_USER (default: $(USER))"
	@echo "k3s-kubeconfig-admin fetch raw admin kubeconfig (emergency use only)"
	@echo "pve-init             generate host secrets (ansible init.yml)"
	@echo "pve-bootstrap        configure the host (ansible site.yml)"
	@echo "ssh-workload         sign SSH cert for k3s nodes  (SSH_PRINCIPAL=$(USER))"
	@echo "ssh-infra            sign SSH cert for PVE host   (SSH_PRINCIPAL=$(USER))"

$(WORKLOAD_CA_FILE) $(INFRA_CA_FILE):
	@echo "missing $@; generate the CA first (see ssh-ca/README.md)" >&2; exit 1

images:
	cd packer && sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} PKR_VAR_ ./deploy.sh $(PACKER_ARGS)'

image-k3s:
	cd packer && sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} PKR_VAR_ ./deploy.sh -only="ubuntu-k3s.proxmox-iso.ubuntu-k3s" $(PACKER_ARGS)'

image-docker:
	cd packer && sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} PKR_VAR_ ./deploy.sh -only="ubuntu-docker.proxmox-iso.ubuntu-docker" $(PACKER_ARGS)'

k3s-disk-setup:
	ansible-playbook -i '$(TF_DIR)/../ansible/inventory.ini' k3s-cluster/provision/ansible/disk-setup.yml

k3s-plan k3s-apply k3s-destroy: | $(WORKLOAD_CA_FILE)

k3s-plan:
	cd $(TF_DIR) && TF_VAR_ssh_ca_public_key='$(WORKLOAD_CA)' \
		sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} TF_VAR_ terraform plan'

k3s-apply:
	cd $(TF_DIR) && TF_VAR_ssh_ca_public_key='$(WORKLOAD_CA)' \
		sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} TF_VAR_ sh -c "stty sane; terraform apply"'

k3s-destroy:
	cd $(TF_DIR) && TF_VAR_ssh_ca_public_key='$(WORKLOAD_CA)' \
		sops exec-file secrets.sops.yaml '$(SOPS_EXEC) {} TF_VAR_ sh -c "stty sane; terraform destroy"'

k3s-kubeconfig:
	@SERVER_IP=$$(cd $(TF_DIR) && terraform output -raw server_ip) && \
	TOKEN=$$(ssh ops@$$SERVER_IP \
		"sudo k3s kubectl get secret $(K8S_USER)-token -n kube-system -o jsonpath='{.data.token}'" \
		| base64 -d) && \
	ssh ops@$$SERVER_IP \
		"sudo k3s kubectl get secret $(K8S_USER)-token -n kube-system -o jsonpath='{.data.ca\.crt}'" \
		| base64 -d > /tmp/$(K8S_USER)-ca.crt && \
	kubectl config set-cluster $(CLUSTER_NAME) \
		--server=https://$$SERVER_IP:6443 \
		--certificate-authority=/tmp/$(K8S_USER)-ca.crt \
		--embed-certs=true && \
	kubectl config set-credentials $(K8S_USER) --token="$$TOKEN" && \
	kubectl config set-context $(CLUSTER_NAME) --cluster=$(CLUSTER_NAME) --user=$(K8S_USER) && \
	kubectl config use-context $(CLUSTER_NAME) && \
	rm -f /tmp/$(K8S_USER)-ca.crt && \
	echo "kubeconfig set to context homelab (user: $(K8S_USER))"

k3s-kubeconfig-admin:
	@SERVER_IP=$$(cd $(TF_DIR) && terraform output -raw server_ip) && \
	ssh ops@$$SERVER_IP "sudo cp /etc/rancher/k3s/k3s.yaml /tmp/k3s.yaml && sudo chmod 644 /tmp/k3s.yaml" && \
	scp ops@$$SERVER_IP:/tmp/k3s.yaml $(KUBECONFIG_ADMIN) && \
	sed -i "s|127.0.0.1|$$SERVER_IP|g; s|default|$(CLUSTER_NAME)-admin|g" $(KUBECONFIG_ADMIN) && \
	echo "Admin kubeconfig saved to $(KUBECONFIG_ADMIN)"

ssh-workload:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) ssh-ca/sign.sh workload $(SSH_PRINCIPAL) 8h $(SSH_PUBKEY)

ssh-infra:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) ssh-ca/sign.sh infra $(SSH_PRINCIPAL) 1h $(SSH_PUBKEY)

pve-init:
	cd pve-bootstrap && $(ANSIBLE) init.yml

pve-bootstrap: | $(INFRA_CA_FILE)
	cd pve-bootstrap && $(ANSIBLE) site.yml \
		-e '{"pve_security_ssh_ca_public_key": "$(INFRA_CA)"}'

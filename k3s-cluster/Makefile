ROOT              := $(CURDIR)/..
CONFIG_SOPS       := $(ROOT)/config.sops.yaml
SOPS_EXEC         := python3 $(ROOT)/scripts/sops-exec.py
TF_DIR            := provision/production
ANSIBLE_DIR       := provision/ansible
GARAGE_TF_DIR     := resources/garage
SEAWEEDFS_TF_DIR  := resources/seaweedfs
USERS_TF_DIR      := resources/k8s-users
NODES_TF_DIR      := resources/k8s-nodes
INVENTORY         := $(ANSIBLE_DIR)/inventory.ini
ANSIBLE           ?= ansible-playbook

WORKLOAD_CA_FILE  := $(ROOT)/ssh-ca/workload/ca.pub
WORKLOAD_CA        = $(shell cat $(WORKLOAD_CA_FILE) 2>/dev/null)

SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt
CLUSTER_NAME      ?= homelab
KUBECONFIG_ADMIN  ?= $(HOME)/.kube/$(CLUSTER_NAME)-admin.yaml
K8S_USER          ?= $(USER)
GITHUB_OWNER      ?= ares-b
GITHUB_REPO       ?= homelab
FLUX_PATH         ?= gitops/clusters/production
SEALED_SECRETS_KEY ?= gitops/clusters/production/sealed-secrets/sealed-secrets-key.sops.yaml

export ANSIBLE_CONFIG := $(ROOT)/ansible.cfg

.PHONY: help plan apply destroy configure wait bootstrap garage-layout \
        garage-init garage-plan garage-apply garage-destroy \
        seaweedfs-init seaweedfs-plan seaweedfs-apply seaweedfs-destroy \
        users-init users-plan users-apply users-destroy \
        nodes-init nodes-plan nodes-apply nodes-destroy \
        kubeconfig kubeconfig-admin drain uncordon shutdown

help:
	@echo "plan             terraform plan"
	@echo "apply            terraform apply (provisions VMs; k3s installs via cloud-init)"
	@echo "destroy          terraform destroy"
	@echo "configure        ansible: node prep, disks (LVM), firewall (run after apply)"
	@echo "users-apply      terraform apply k8s users (ServiceAccounts + RBAC)"
	@echo "users-plan       terraform plan k8s users"
	@echo "users-destroy    terraform destroy k8s users"
	@echo "nodes-apply      terraform apply node storage labels"
	@echo "nodes-plan       terraform plan node storage labels"
	@echo "nodes-destroy    terraform destroy node storage labels"
	@echo "bootstrap        flux bootstrap + sealed-secrets key + garage layout"
	@echo "garage-layout    initialize garage cluster layout (idempotent)"
	@echo "garage-plan      terraform plan for garage buckets/keys"
	@echo "garage-apply     terraform apply (port-forwards admin API, creates sealed secrets)"
	@echo "garage-destroy   terraform destroy garage buckets/keys"
	@echo "seaweedfs-plan   terraform plan for seaweedfs buckets/cors"
	@echo "seaweedfs-apply  terraform apply (port-forwards S3 API, creates buckets/cors)"
	@echo "seaweedfs-destroy terraform destroy seaweedfs buckets/cors"
	@echo "kubeconfig       write kubeconfig for K8S_USER (default: $(USER))"
	@echo "kubeconfig-admin fetch raw admin kubeconfig (emergency use only)"
	@echo "drain            drain worker nodes before shutdown"
	@echo "uncordon         uncordon worker nodes after startup"
	@echo "shutdown         drain workers, shutdown all k3s VMs, then PVE host"

$(WORKLOAD_CA_FILE):
	@echo "missing $@; generate the CA first (see ssh-ca/README.md)" >&2; exit 1

plan apply destroy: | $(WORKLOAD_CA_FILE)

plan:
	cd $(TF_DIR) && TF_VAR_ssh_ca_public_key='$(WORKLOAD_CA)' \
		sops exec-file $(CONFIG_SOPS) '$(SOPS_EXEC) {} TF_VAR_ k3s_provision terraform plan'

apply:
	cd $(TF_DIR) && TF_VAR_ssh_ca_public_key='$(WORKLOAD_CA)' \
		sops exec-file $(CONFIG_SOPS) '$(SOPS_EXEC) {} TF_VAR_ k3s_provision sh -c "stty sane; terraform apply"'

destroy:
	cd $(TF_DIR) && TF_VAR_ssh_ca_public_key='$(WORKLOAD_CA)' \
		sops exec-file $(CONFIG_SOPS) '$(SOPS_EXEC) {} TF_VAR_ k3s_provision sh -c "stty sane; terraform destroy"'

wait:
	@echo "Waiting for k3s nodes to be reachable..."
	@until ansible k3s -i $(INVENTORY) -m ping --timeout=5 >/dev/null 2>&1; do sleep 15; done

configure: wait
	$(ANSIBLE) -i $(INVENTORY) $(ANSIBLE_DIR)/site.yml

bootstrap: | $(WORKLOAD_CA_FILE)
	$(MAKE) kubeconfig-admin
	flux bootstrap github \
		--owner=$(GITHUB_OWNER) \
		--repository=$(GITHUB_REPO) \
		--path=$(FLUX_PATH) \
		--personal
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl wait deployment sealed-secrets-controller \
		-n sealed-secrets --for=condition=available --timeout=5m
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl delete secret -n sealed-secrets \
		-l sealedsecrets.bitnami.com/sealed-secrets-key
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops -d $(SEALED_SECRETS_KEY) \
		| KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl apply -f -
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl rollout restart deployment/sealed-secrets-controller \
		-n sealed-secrets
	$(MAKE) garage-layout

garage-layout:
	@echo "Waiting for Garage StatefulSet..."
	@until KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl get statefulset garage -n garage >/dev/null 2>&1; \
		do sleep 15; done
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl rollout status statefulset/garage \
		-n garage --timeout=15m
	@TOKEN=$$(KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl get secret garage-admin -n garage \
		-o jsonpath='{.data.admin-token}' | base64 -d) && \
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl run garage-layout-init -n garage \
		--rm -i --restart=Never \
		--image=python:3.13-alpine \
		--env="GARAGE_ADMIN_TOKEN=$$TOKEN" \
		-- python3 -u - < $(ROOT)/scripts/garage-layout-init.py

garage-init:
	cd $(GARAGE_TF_DIR) && terraform init

garage-plan garage-apply garage-destroy:
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl port-forward svc/garage 3903:3903 -n garage & \
	PF_PID=$$!; sleep 2; \
	cd $(GARAGE_TF_DIR) && sops exec-file $(CONFIG_SOPS) '$(SOPS_EXEC) {} TF_VAR_ garage terraform $(subst garage-,,$@) $(if $(filter garage-plan,$@),,-auto-approve)'; \
	kill $$PF_PID 2>/dev/null || true

seaweedfs-init:
	cd $(SEAWEEDFS_TF_DIR) && terraform init

seaweedfs-plan seaweedfs-apply seaweedfs-destroy:
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl port-forward svc/seaweedfs-s3 8333:8333 -n seaweedfs & \
	PF_PID=$$!; sleep 2; \
	cd $(SEAWEEDFS_TF_DIR) && sops exec-file $(CONFIG_SOPS) '$(SOPS_EXEC) {} TF_VAR_ seaweedfs terraform $(subst seaweedfs-,,$@) $(if $(filter seaweedfs-plan,$@),,-auto-approve)'; \
	kill $$PF_PID 2>/dev/null || true

users-init:
	cd $(USERS_TF_DIR) && terraform init

users-plan users-apply users-destroy:
	cd $(USERS_TF_DIR) && TF_VAR_kubeconfig_path=$(KUBECONFIG_ADMIN) \
		terraform $(subst users-,,$@) $(if $(filter users-plan,$@),,-auto-approve)

nodes-init:
	cd $(NODES_TF_DIR) && terraform init

nodes-plan nodes-apply nodes-destroy:
	cd $(NODES_TF_DIR) && TF_VAR_kubeconfig_path=$(KUBECONFIG_ADMIN) \
		sops exec-file $(CONFIG_SOPS) '$(SOPS_EXEC) {} TF_VAR_ k3s_provision terraform $(subst nodes-,,$@) $(if $(filter nodes-plan,$@),,-auto-approve)'

kubeconfig:
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
	echo "kubeconfig set to context $(CLUSTER_NAME) (user: $(K8S_USER))"

kubeconfig-admin:
	@SERVER_IP=$$(cd $(TF_DIR) && terraform output -raw server_ip) && \
	ssh ops@$$SERVER_IP "sudo cp /etc/rancher/k3s/k3s.yaml /tmp/k3s.yaml && sudo chmod 644 /tmp/k3s.yaml" && \
	scp ops@$$SERVER_IP:/tmp/k3s.yaml $(KUBECONFIG_ADMIN) && \
	sed -i "s|127.0.0.1|$$SERVER_IP|g; s|default|$(CLUSTER_NAME)-admin|g" $(KUBECONFIG_ADMIN) && \
	echo "Admin kubeconfig saved to $(KUBECONFIG_ADMIN)"

drain:
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl delete pdb --all --all-namespaces --ignore-not-found
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl drain k3s-worker-01 --ignore-daemonsets --delete-emptydir-data --timeout=120s
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data --timeout=120s

uncordon:
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl uncordon k3s-worker-01
	KUBECONFIG=$(KUBECONFIG_ADMIN) kubectl uncordon k3s-worker-02

shutdown: drain
	@echo "Shutting down k3s nodes..."
	ssh ops@10.0.0.11 "sudo shutdown -h now" || true
	ssh ops@10.0.0.12 "sudo shutdown -h now" || true
	ssh ops@10.0.0.10 "sudo shutdown -h now" || true
	@echo "Waiting 60s for VMs to power off..."
	@sleep 60
	@echo "Shutting down PVE host..."
	ssh 192.168.0.69 "sudo shutdown -h now"

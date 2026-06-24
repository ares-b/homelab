# Thin dispatcher. Each component owns its own Makefile; this forwards to them.
#
#   k3s-*     -> k3s-cluster   (strip the k3s- prefix)
#   garage-*  -> k3s-cluster   (kept verbatim)
#   pve-*     -> pve-bootstrap (strip the pve- prefix)
#   ssh-*     -> ssh-ca        (strip the ssh- prefix)
#   edge-*    -> edge-access   (strip the edge- prefix)
#   image*    -> packer
#
# Examples: make k3s-apply, make pve-bootstrap, make ssh-workload,
#           make garage-apply, make edge-deploy, make images.

.PHONY: help cluster-shutdown images image-k3s image-docker pve-bootstrap

help:
	@echo "k3s-cluster   : k3s-plan k3s-apply k3s-destroy k3s-configure k3s-bootstrap"
	@echo "                k3s-users-apply k3s-users-plan k3s-users-destroy"
	@echo "                k3s-nodes-apply k3s-nodes-plan k3s-nodes-destroy"
	@echo "                k3s-kubeconfig k3s-kubeconfig-admin k3s-drain k3s-uncordon"
	@echo "                cluster-shutdown garage-init garage-plan garage-apply garage-destroy"
	@echo "pve-bootstrap : pve-setup pve-init pve-bootstrap"
	@echo "ssh-ca        : ssh-init ssh-workload ssh-infra"
	@echo "edge-access   : edge-setup edge-tf-apply edge-tf-destroy edge-deploy edge-vps edge-lxc"
	@echo "packer        : images image-k3s image-docker"
	@echo ""
	@echo "Run 'make -C <dir> help' for component-specific targets."

k3s-%:
	$(MAKE) -C k3s-cluster $*

garage-%:
	$(MAKE) -C k3s-cluster garage-$*

seaweedfs-%:
	$(MAKE) -C k3s-cluster seaweedfs-$*

cluster-shutdown:
	$(MAKE) -C k3s-cluster shutdown

pve-%:
	$(MAKE) -C pve-bootstrap $*

# Explicit recipe: the target name equals the pve-bootstrap/ dir, so a bare
# pattern rule would be shadowed by the existing directory.
pve-bootstrap:
	$(MAKE) -C pve-bootstrap bootstrap

ssh-%:
	$(MAKE) -C ssh-ca $*

edge-%:
	$(MAKE) -C edge-access $*

images image-k3s image-docker:
	$(MAKE) -C packer $@

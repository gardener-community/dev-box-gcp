include tools.mk

REPO_ROOT := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
TERRAFORM_DIR := terraform

box-%: export TF_VAR_name = ${USER}-gardener-dev
box-%: export TF_VAR_user = ${USER}
box-%: export TF_VAR_serviceaccount_file = $(REPO_ROOT)/secrets/gardener-dev.json

.PHONY: box-up
box-up: $(TERRAFORM)
	$(TERRAFORM) -chdir=$(TERRAFORM_DIR) init
	$(TERRAFORM) -chdir=$(TERRAFORM_DIR) apply
	@# we need an additional refresh, otherwise the instance_ip_addr output variable might be outdated
	$(TERRAFORM) -chdir=$(TERRAFORM_DIR) refresh
	@echo -e "\nYou can now connect to your dev box using:"
	@echo "ssh -tl $$TF_VAR_user $$($(TERRAFORM) -chdir=$(TERRAFORM_DIR) output instance_ip_addr | jq -r) ./start-gardener-dev.sh"

.PHONY: box-down
box-down: box-clean-known-hosts $(TERRAFORM)
	$(TERRAFORM) -chdir=$(TERRAFORM_DIR) apply -var desired_status=TERMINATED

.PHONY: box-clean
box-clean: box-clean-known-hosts $(TERRAFORM)
	$(TERRAFORM) -chdir=$(TERRAFORM_DIR) destroy

.PHONY: box-clean-known-hosts
box-clean-known-hosts: $(TERRAFORM)
	instance_ip_addr="$$($(TERRAFORM) -chdir=$(TERRAFORM_DIR) output instance_ip_addr | jq -r)"; \
	[ -z "$$instance_ip_addr" ] || sed -i "/$$instance_ip_addr /d" ~/.ssh/known_hosts

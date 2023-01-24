include tools.mk

REPO_ROOT := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
TERRAFORM_DIR := terraform

# GCP resource names don't allow uppercase characters
box-%: export TF_VAR_name ?= $(shell echo ${USER} | tr '[:upper:]' '[:lower:]')-gardener-dev
box-%: export TF_VAR_user ?= ${USER}
box-%: export TF_VAR_serviceaccount_file ?= $(REPO_ROOT)/secrets/gardener-dev.json

# restrict incoming traffic to dev box to the outgoing IPv4 address of the local device by default
RESTRICT_SOURCE_RANGES ?= yes
ifneq ($(RESTRICT_SOURCE_RANGES),no)
box-%: export TF_VAR_source_ranges ?= ["$(shell curl -sS --ipv4 https://ifconfig.me)/32"]
endif

.PHONY: box-up
box-up: $(TERRAFORM)
	$(TERRAFORM) -chdir=$(TERRAFORM_DIR) init
	$(TERRAFORM) -chdir=$(TERRAFORM_DIR) apply
	@# we need an additional refresh, otherwise the instance_ip_addr output variable might be outdated
	$(TERRAFORM) -chdir=$(TERRAFORM_DIR) refresh
	@echo "You can now connect to your dev box using:"
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

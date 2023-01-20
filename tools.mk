#########################################
# Tool path and version variables       #
#########################################

TOOLS_BIN_DIR ?= bin
TERRAFORM := $(TOOLS_BIN_DIR)/terraform

# default tool versions
TERRAFORM_VERSION ?= 1.3.7

# export TOOLS_BIN_DIR and add it to PATH so that all scripts can use it
export TOOLS_BIN_DIR := $(TOOLS_BIN_DIR)
export PATH := $(abspath $(TOOLS_BIN_DIR)):$(PATH)

#########################################
# Common                                #
#########################################

# We use a file per tool and version as an indicator for make whether we need to install the tool or a different
# version of the tool (make doesn't rerun the rule if the rule is changed).

# Use this "function" to add the version file as a prerequisite for the tool target: e.g.
#   $(FOO): $(call tool_version_file,$(FOO),$(FOO_VERSION))
tool_version_file = $(TOOLS_BIN_DIR)/.version_$(subst $(TOOLS_BIN_DIR)/,,$(1))_$(2)

# This target cleans up any previous version files for the given tool and creates the given version file.
# This way, we can generically determine, which version was installed without calling each and every binary explicitly.
$(TOOLS_BIN_DIR)/.version_%:
	@version_file=$@; rm -f $${version_file%_*}*
	@touch $@

.PHONY: clean-tools-bin
clean-tools-bin:
	rm -rf $(TOOLS_BIN_DIR)/*

#########################################
# Tools                                 #
#########################################

$(TERRAFORM): $(call tool_version_file,$(TERRAFORM),$(TERRAFORM_VERSION))
	TMP_DIR=$$(mktemp -d); \
		curl -Lo $$TMP_DIR/terraform.zip https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_$(shell uname -s | tr '[:upper:]' '[:lower:]')_$(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').zip; \
		unzip -DDo $$TMP_DIR/terraform.zip terraform -d $(TOOLS_BIN_DIR)
	chmod +x $(TERRAFORM)

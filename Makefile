# =============================================================================
# Infrastructure Deployment Makefile
# =============================================================================
# Orchestrates Terraform/OpenTofu workflows for provisioning downstream
# RKE2 clusters via Rancher Server.
# =============================================================================

.PHONY: help init plan apply destroy export-outputs

# Configuration
TF_DIR := $(shell pwd)
TF_OUTPUT_JSON := $(TF_DIR)/.terraform-outputs.json

# Detect Terraform/OpenTofu binary
TF_BINARY := $(shell command -v tofu >/dev/null 2>&1 && echo "tofu" || echo "terraform")

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform/OpenTofu
	cd $(TF_DIR) && $(TF_BINARY) init

plan: ## Plan Terraform changes
	cd $(TF_DIR) && $(TF_BINARY) plan -lock=false

apply: ## Apply Terraform changes (auto-approve, no lock)
	cd $(TF_DIR) && $(TF_BINARY) apply -auto-approve -lock=false
	@$(MAKE) export-outputs

destroy: ## Destroy Terraform infrastructure (auto-approve, no lock)
	cd $(TF_DIR) && $(TF_BINARY) destroy -auto-approve -lock=false

export-outputs: ## Export Terraform outputs to JSON file
	@echo "Exporting Terraform outputs..." >&2
	@cd $(TF_DIR) && $(TF_BINARY) output -json > $(TF_OUTPUT_JSON) 2>/dev/null || (echo "Error: Terraform outputs not available. Run 'make apply' first." >&2 && exit 1)
	@echo "Terraform outputs exported to $(TF_OUTPUT_JSON)" >&2

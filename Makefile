# Adowol EKS Platform — operator entrypoints.
# Terraform is applied LOCALLY (per the platform design). CI only builds images
# and bumps GitOps tags; it never shapes infrastructure.

SHELL := /bin/bash
.DEFAULT_GOAL := help

REGION         ?= us-east-1
BACKEND        := $(CURDIR)/terraform/backend.hcl
STATE_BUCKET   := $(shell awk -F'"' '/^[[:space:]]*bucket/{print $$2}' $(BACKEND) 2>/dev/null)

FOUNDATION := terraform/layers/10-foundation
COMPUTE    := terraform/layers/20-compute
ADDONS     := terraform/layers/30-addons

# Layers (except bootstrap) read remote state and the region from these.
export TF_VAR_state_bucket := $(STATE_BUCKET)
export TF_VAR_region       := $(REGION)

CLUSTER := adowol-dev

# ---------------------------------------------------------------------------
.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ---- Bootstrap (run once) -------------------------------------------------
.PHONY: bootstrap
bootstrap: ## Create the remote-state S3 bucket (run once). Set BUCKET=<globally-unique-name>
	@test -n "$(BUCKET)" || { echo "ERROR: pass BUCKET=<globally-unique-name>"; exit 1; }
	cd terraform/bootstrap && terraform init && \
		terraform apply -var="state_bucket_name=$(BUCKET)" -var="region=$(REGION)"
	@echo ""
	@echo ">>> Now create terraform/backend.hcl from the bootstrap output:"
	@echo ">>>   cd terraform/bootstrap && terraform output -raw backend_hcl > ../backend.hcl"

# ---- Per-layer plan/apply -------------------------------------------------
.PHONY: foundation-apply compute-apply addons-apply
foundation-apply: _check-backend ## Apply the foundation layer (VPC, ECR, IAM/OIDC, KMS)
	cd $(FOUNDATION) && terraform init -reconfigure -backend-config=$(BACKEND) && terraform apply

compute-apply: _check-backend ## Apply the compute layer (EKS Auto Mode)
	cd $(COMPUTE) && terraform init -reconfigure -backend-config=$(BACKEND) && terraform apply

addons-apply: _check-backend ## Apply the addons layer (bootstrap Argo CD + root app)
	cd $(ADDONS) && terraform init -reconfigure -backend-config=$(BACKEND) && terraform apply

.PHONY: up
up: foundation-apply compute-apply addons-apply ## Apply all layers in order

# ---- Destroy (reverse order) ----------------------------------------------
.PHONY: down
down: _check-backend ## Destroy all layers (reverse order). Leaves the state bucket.
	cd $(ADDONS)     && terraform init -reconfigure -backend-config=$(BACKEND) && terraform destroy
	cd $(COMPUTE)    && terraform init -reconfigure -backend-config=$(BACKEND) && terraform destroy
	cd $(FOUNDATION) && terraform init -reconfigure -backend-config=$(BACKEND) && terraform destroy

# ---- Cluster / Argo CD helpers --------------------------------------------
.PHONY: kubeconfig
kubeconfig: ## Point kubectl at the cluster
	aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER)

.PHONY: argocd-password
argocd-password: ## Print the initial Argo CD admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

.PHONY: argocd-ui
argocd-ui: ## Port-forward the Argo CD UI to https://localhost:8080
	kubectl -n argocd port-forward svc/argocd-server 8080:443

.PHONY: ingress-url
ingress-url: ## Print the demo app's public ALB hostname
	@kubectl -n demo get ingress platform -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo

# ---- App dev --------------------------------------------------------------
.PHONY: test
test: ## Run all service tests (Go + frontend)
	cd services/service-a && go test ./...
	cd services/service-b && go test ./...
	cd services/frontend  && npm test

.PHONY: fmt
fmt: ## terraform fmt across all layers
	terraform fmt -recursive terraform

.PHONY: validate
validate: ## terraform validate every layer (no backend)
	@for d in terraform/bootstrap $(FOUNDATION) $(COMPUTE) $(ADDONS); do \
		echo "== $$d =="; \
		( cd $$d && terraform init -backend=false -input=false >/dev/null && terraform validate ) || exit 1; \
	done

# ---------------------------------------------------------------------------
.PHONY: _check-backend
_check-backend:
	@test -f $(BACKEND) || { echo "ERROR: terraform/backend.hcl missing. Run 'make bootstrap' then create it (see help)."; exit 1; }
	@test -n "$(STATE_BUCKET)" || { echo "ERROR: could not read bucket from $(BACKEND)"; exit 1; }

# Happy Speller CI/CD Automation Makefile
# Usage: make <target>

# Default shell
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
RED := \033[0;31m
NC := \033[0m # No Color

# Configuration
APP_NAME := happy-speller
NAMESPACE := demo
REGISTRY := registry.local:5000
BUILD_NUMBER := $(shell date +%Y%m%d%H%M%S)
SHORT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "local")
IMAGE_TAG := $(REGISTRY)/$(APP_NAME):$(BUILD_NUMBER)-$(SHORT_COMMIT)
LATEST_TAG := $(REGISTRY)/$(APP_NAME):latest

# Environment detection
KUBECONFIG ?= ~/.kube/config
MINIO_BASE ?= http://192.168.68.58:9000
JENKINS_BASE ?= http://192.168.50.247:8080
GITEA_BASE ?= http://192.168.50.130:3000

# Default target
.PHONY: help
help: ## Show this help message
	@echo -e "$(BLUE)Happy Speller CI/CD Automation$(NC)"
	@echo -e "$(BLUE)================================$(NC)"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development targets
.PHONY: install
install: ## Install dependencies
	@echo -e "$(BLUE)[INFO]$(NC) Installing Node.js dependencies..."
	cd app && npm install
	@echo -e "$(GREEN)[SUCCESS]$(NC) Dependencies installed"

.PHONY: lint
lint: ## Run ESLint
	@echo -e "$(BLUE)[INFO]$(NC) Running ESLint..."
	cd app && npm run lint
	@echo -e "$(GREEN)[SUCCESS]$(NC) Linting completed"

.PHONY: lint-fix
lint-fix: ## Fix ESLint issues automatically
	@echo -e "$(BLUE)[INFO]$(NC) Fixing ESLint issues..."
	cd app && npm run lint:fix
	@echo -e "$(GREEN)[SUCCESS]$(NC) Linting issues fixed"

.PHONY: test
test: ## Run tests
	@echo -e "$(BLUE)[INFO]$(NC) Running tests..."
	cd app && npm test
	@echo -e "$(GREEN)[SUCCESS]$(NC) Tests completed"

.PHONY: test-coverage
test-coverage: ## Run tests with coverage report
	@echo -e "$(BLUE)[INFO]$(NC) Running tests with coverage..."
	cd app && npm test -- --coverage
	@echo -e "$(GREEN)[SUCCESS]$(NC) Tests with coverage completed"
	@echo -e "$(BLUE)[INFO]$(NC) Coverage report available at app/coverage/lcov-report/index.html"

.PHONY: dev
dev: ## Start development server
	@echo -e "$(BLUE)[INFO]$(NC) Starting development server..."
	cd app && npm run dev

.PHONY: start
start: ## Start production server
	@echo -e "$(BLUE)[INFO]$(NC) Starting production server..."
	cd app && npm start

# Build targets
.PHONY: build
build: install lint test ## Build application (install, lint, test)
	@echo -e "$(GREEN)[SUCCESS]$(NC) Application build completed"

.PHONY: build-image
build-image: ## Build Docker image
	@echo -e "$(BLUE)[INFO]$(NC) Building Docker image..."
	@echo -e "$(BLUE)[INFO]$(NC) Image tag: $(IMAGE_TAG)"
	cd app && docker build -t $(IMAGE_TAG) -t $(LATEST_TAG) .
	@echo -e "$(GREEN)[SUCCESS]$(NC) Docker image built: $(IMAGE_TAG)"

.PHONY: push-image
push-image: build-image ## Push Docker image to registry
	@echo -e "$(BLUE)[INFO]$(NC) Pushing Docker image to registry..."
	docker push $(IMAGE_TAG)
	docker push $(LATEST_TAG)
	@echo -e "$(GREEN)[SUCCESS]$(NC) Docker image pushed to registry"

# Infrastructure targets
.PHONY: terraform-init
terraform-init: ## Initialize Terraform
	@echo -e "$(BLUE)[INFO]$(NC) Initializing Terraform..."
	cd infra/terraform && terraform init
	@echo -e "$(GREEN)[SUCCESS]$(NC) Terraform initialized"

.PHONY: terraform-plan
terraform-plan: terraform-init ## Plan Terraform changes
	@echo -e "$(BLUE)[INFO]$(NC) Planning Terraform changes..."
	@if [ ! -f infra/terraform/terraform.tfvars ]; then \
		echo -e "$(YELLOW)[WARNING]$(NC) terraform.tfvars not found, using defaults"; \
	fi
	cd infra/terraform && terraform plan
	@echo -e "$(GREEN)[SUCCESS]$(NC) Terraform plan completed"

.PHONY: terraform-apply
terraform-apply: terraform-init ## Apply Terraform changes
	@echo -e "$(BLUE)[INFO]$(NC) Applying Terraform changes..."
	@if [ -z "$(MINIO_ACCESS_KEY)" ] || [ -z "$(MINIO_SECRET_KEY)" ]; then \
		echo -e "$(RED)[ERROR]$(NC) MINIO_ACCESS_KEY and MINIO_SECRET_KEY must be set"; \
		exit 1; \
	fi
	cd infra/terraform && terraform apply -auto-approve \
		-var="minio_access_key=$(MINIO_ACCESS_KEY)" \
		-var="minio_secret_key=$(MINIO_SECRET_KEY)" \
		-var="grafana_admin_password=$(GRAFANA_ADMIN_PASSWORD)"
	@echo -e "$(GREEN)[SUCCESS]$(NC) Terraform applied successfully"

.PHONY: terraform-destroy
terraform-destroy: ## Destroy Terraform resources
	@echo -e "$(YELLOW)[WARNING]$(NC) This will destroy all Terraform-managed resources!"
	@read -p "Are you sure? [y/N] " -n 1 -r; echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo -e "$(BLUE)[INFO]$(NC) Destroying Terraform resources..."; \
		cd infra/terraform && terraform destroy -auto-approve; \
		echo -e "$(GREEN)[SUCCESS]$(NC) Terraform resources destroyed"; \
	else \
		echo -e "$(BLUE)[INFO]$(NC) Terraform destroy cancelled"; \
	fi

.PHONY: ansible-setup
ansible-setup: ## Run Ansible playbook for Jenkins setup
	@echo -e "$(BLUE)[INFO]$(NC) Running Ansible playbook for Jenkins setup..."
	@if [ -z "$(JENKINS_TOKEN)" ] || [ -z "$(GITEA_TOKEN)" ]; then \
		echo -e "$(RED)[ERROR]$(NC) JENKINS_TOKEN and GITEA_TOKEN must be set"; \
		exit 1; \
	fi
	cd infra/ansible && ansible-playbook jenkins-setup.yaml
	@echo -e "$(GREEN)[SUCCESS]$(NC) Ansible setup completed"

.PHONY: bootstrap
bootstrap: terraform-apply ansible-setup seed-minio ## Bootstrap complete infrastructure
	@echo -e "$(GREEN)[SUCCESS]$(NC) Infrastructure bootstrap completed!"
	@echo -e "$(BLUE)[INFO]$(NC) Services available:"
	@echo -e "  - Jenkins: $(JENKINS_BASE)"
	@echo -e "  - Gitea: $(GITEA_BASE)"
	@echo -e "  - MinIO: $(MINIO_BASE)"
	@echo -e "  - Kubernetes: kubectl -n $(NAMESPACE) get pods"

# Deployment targets
.PHONY: deploy
deploy: ## Deploy application to Kubernetes
	@echo -e "$(BLUE)[INFO]$(NC) Deploying application to Kubernetes..."
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(APP_NAME) ./helm/app \
		--namespace $(NAMESPACE) \
		--set image.repository=$(REGISTRY)/$(APP_NAME) \
		--set image.tag=$(BUILD_NUMBER)-$(SHORT_COMMIT) \
		--set replicaCount=2 \
		--wait --timeout=300s
	@echo -e "$(GREEN)[SUCCESS]$(NC) Application deployed successfully"

.PHONY: deploy-local
deploy-local: build-image deploy ## Build and deploy locally
	@echo -e "$(GREEN)[SUCCESS]$(NC) Local build and deploy completed"

.PHONY: undeploy
undeploy: ## Remove application from Kubernetes
	@echo -e "$(BLUE)[INFO]$(NC) Removing application from Kubernetes..."
	-helm uninstall $(APP_NAME) --namespace $(NAMESPACE)
	@echo -e "$(GREEN)[SUCCESS]$(NC) Application removed"

.PHONY: redeploy
redeploy: undeploy deploy ## Redeploy application (remove and deploy again)
	@echo -e "$(GREEN)[SUCCESS]$(NC) Application redeployed"

# MinIO targets
.PHONY: seed-minio
seed-minio: ## Setup MinIO buckets and seed with sample data
	@echo -e "$(BLUE)[INFO]$(NC) Setting up MinIO buckets and seeding data..."
	@if [ ! -x scripts/seed-minio.sh ]; then \
		chmod +x scripts/seed-minio.sh; \
	fi
	./scripts/seed-minio.sh
	@echo -e "$(GREEN)[SUCCESS]$(NC) MinIO setup completed"

.PHONY: minio-status
minio-status: ## Check MinIO status and list buckets
	@echo -e "$(BLUE)[INFO]$(NC) Checking MinIO status..."
	@if command -v mc &> /dev/null; then \
		mc alias set local-minio $(MINIO_BASE) $(MINIO_ACCESS_KEY) $(MINIO_SECRET_KEY) --api S3v4 2>/dev/null || true; \
		echo -e "$(BLUE)[INFO]$(NC) MinIO buckets:"; \
		mc ls local-minio 2>/dev/null || echo -e "$(YELLOW)[WARNING]$(NC) Could not list buckets"; \
	else \
		echo -e "$(YELLOW)[WARNING]$(NC) mc client not installed"; \
		curl -s $(MINIO_BASE)/minio/health/live && echo -e "$(GREEN)[SUCCESS]$(NC) MinIO is healthy" || echo -e "$(RED)[ERROR]$(NC) MinIO is not accessible"; \
	fi

# Monitoring and debugging targets
.PHONY: status
status: ## Check application and infrastructure status
	@echo -e "$(BLUE)[INFO]$(NC) Checking system status..."
	@echo -e "$(BLUE)=== Kubernetes Status ===$(NC)"
	-kubectl -n $(NAMESPACE) get pods -l app=$(APP_NAME)
	-kubectl -n $(NAMESPACE) get svc $(APP_NAME)
	@echo -e "$(BLUE)=== Application Health ===$(NC)"
	@if kubectl -n $(NAMESPACE) get svc $(APP_NAME) &>/dev/null; then \
		kubectl -n $(NAMESPACE) port-forward svc/$(APP_NAME) 8080:8080 & \
		sleep 2; \
		curl -s http://localhost:8080/healthz || echo -e "$(YELLOW)[WARNING]$(NC) Health check failed"; \
		pkill -f "kubectl.*port-forward" 2>/dev/null || true; \
	fi
	@echo ""

.PHONY: logs
logs: ## Show application logs
	@echo -e "$(BLUE)[INFO]$(NC) Showing application logs..."
	kubectl -n $(NAMESPACE) logs -l app=$(APP_NAME) --tail=100 -f

.PHONY: describe
describe: ## Describe Kubernetes resources
	@echo -e "$(BLUE)[INFO]$(NC) Describing Kubernetes resources..."
	kubectl -n $(NAMESPACE) describe deployment $(APP_NAME)
	kubectl -n $(NAMESPACE) describe service $(APP_NAME)
	kubectl -n $(NAMESPACE) describe pods -l app=$(APP_NAME)

.PHONY: shell
shell: ## Get shell access to application pod
	@echo -e "$(BLUE)[INFO]$(NC) Opening shell in application pod..."
	kubectl -n $(NAMESPACE) exec -it deployment/$(APP_NAME) -- sh

.PHONY: port-forward
port-forward: ## Port forward to access application locally
	@echo -e "$(BLUE)[INFO]$(NC) Port forwarding to application (http://localhost:8080)..."
	@echo -e "$(YELLOW)[NOTE]$(NC) Press Ctrl+C to stop port forwarding"
	kubectl -n $(NAMESPACE) port-forward svc/$(APP_NAME) 8080:8080

# Testing targets
.PHONY: test-integration
test-integration: ## Run integration tests against deployed application
	@echo -e "$(BLUE)[INFO]$(NC) Running integration tests..."
	@kubectl -n $(NAMESPACE) run integration-test --rm -i --restart=Never \
		--image=curlimages/curl:8.2.1 -- \
		sh -c "curl -f http://$(APP_NAME):8080/healthz && curl -f http://$(APP_NAME):8080/api/version"
	@echo -e "$(GREEN)[SUCCESS]$(NC) Integration tests passed"

.PHONY: load-test
load-test: ## Run basic load test
	@echo -e "$(BLUE)[INFO]$(NC) Running basic load test..."
	@if command -v ab &> /dev/null; then \
		kubectl -n $(NAMESPACE) port-forward svc/$(APP_NAME) 8080:8080 & \
		sleep 2; \
		ab -n 100 -c 10 http://localhost:8080/healthz; \
		pkill -f "kubectl.*port-forward" 2>/dev/null || true; \
	else \
		echo -e "$(YELLOW)[WARNING]$(NC) Apache Bench (ab) not installed, skipping load test"; \
		echo -e "$(BLUE)[INFO]$(NC) Install with: brew install apache2 (macOS) or apt-get install apache2-utils (Ubuntu)"; \
	fi

# Cleanup targets
.PHONY: clean
clean: ## Clean build artifacts and temporary files
	@echo -e "$(BLUE)[INFO]$(NC) Cleaning build artifacts..."
	-rm -rf app/coverage
	-rm -f app/junit.xml
	-rm -rf app/node_modules/.cache
	-docker system prune -f
	@echo -e "$(GREEN)[SUCCESS]$(NC) Cleanup completed"

.PHONY: clean-all
clean-all: clean undeploy ## Clean everything including deployments
	@echo -e "$(BLUE)[INFO]$(NC) Performing complete cleanup..."
	-docker rmi $(IMAGE_TAG) $(LATEST_TAG) 2>/dev/null || true
	@echo -e "$(GREEN)[SUCCESS]$(NC) Complete cleanup finished"

# CI/CD pipeline simulation
.PHONY: ci
ci: build build-image test-integration ## Simulate CI pipeline (build, image, test)
	@echo -e "$(GREEN)[SUCCESS]$(NC) CI pipeline completed successfully"

.PHONY: cd
cd: ci deploy ## Simulate CD pipeline (CI + deploy)
	@echo -e "$(GREEN)[SUCCESS]$(NC) CD pipeline completed successfully"

.PHONY: pipeline
pipeline: bootstrap ci deploy ## Run complete pipeline (bootstrap + CI + deploy)
	@echo -e "$(GREEN)[SUCCESS]$(NC) Complete pipeline executed successfully!"
	@echo -e "$(BLUE)[INFO]$(NC) Application is now ready at: kubectl -n $(NAMESPACE) port-forward svc/$(APP_NAME) 8080:8080"

# GitOps targets
.PHONY: gitops-install
gitops-install: ## Install ArgoCD for GitOps
	@echo -e "$(BLUE)[INFO]$(NC) Installing ArgoCD..."
	./gitops/bootstrap/install-argocd.sh
	@echo -e "$(GREEN)[SUCCESS]$(NC) ArgoCD installation completed"

.PHONY: gitops-deploy
gitops-deploy: ## Deploy applications via GitOps
	@echo -e "$(BLUE)[INFO]$(NC) Deploying applications via ArgoCD..."
	kubectl apply -f gitops/applications/
	@echo -e "$(GREEN)[SUCCESS]$(NC) GitOps applications deployed"

.PHONY: gitops-status
gitops-status: ## Check GitOps deployment status
	@echo -e "$(BLUE)[INFO]$(NC) Checking GitOps status..."
	./scripts/gitops/status.sh

.PHONY: gitops-promote
gitops-promote: ## Promote from dev to staging (interactive)
	@echo -e "$(BLUE)[INFO]$(NC) Starting promotion from dev to staging..."
	./scripts/gitops/promote.sh dev staging

.PHONY: gitops-promote-prod
gitops-promote-prod: ## Promote from staging to production (interactive)
	@echo -e "$(BLUE)[INFO]$(NC) Starting promotion from staging to production..."
	./scripts/gitops/promote.sh staging prod

.PHONY: argocd-ui
argocd-ui: ## Open ArgoCD UI (port-forward)
	@echo -e "$(BLUE)[INFO]$(NC) Starting port-forward to ArgoCD UI..."
	@echo -e "$(YELLOW)[NOTE]$(NC) ArgoCD UI will be available at http://localhost:8080"
	@echo -e "$(YELLOW)[NOTE]$(NC) Username: admin, Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo 'Not available')"
	@echo -e "$(YELLOW)[NOTE]$(NC) Press Ctrl+C to stop port-forward"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

# Version and information targets
.PHONY: version
version: ## Show version information
	@echo -e "$(BLUE)Happy Speller CI/CD Pipeline$(NC)"
	@echo -e "$(BLUE)=============================$(NC)"
	@echo "App Name: $(APP_NAME)"
	@echo "Namespace: $(NAMESPACE)"
	@echo "Registry: $(REGISTRY)"
	@echo "Build Number: $(BUILD_NUMBER)"
	@echo "Commit: $(SHORT_COMMIT)"
	@echo "Image Tag: $(IMAGE_TAG)"
	@echo ""
	@echo -e "$(BLUE)Environment:$(NC)"
	@echo "KUBECONFIG: $(KUBECONFIG)"
	@echo "MINIO_BASE: $(MINIO_BASE)"
	@echo "JENKINS_BASE: $(JENKINS_BASE)"
	@echo "GITEA_BASE: $(GITEA_BASE)"

.PHONY: env
env: ## Show environment variables
	@echo -e "$(BLUE)Required Environment Variables:$(NC)"
	@echo "MINIO_ACCESS_KEY: $${MINIO_ACCESS_KEY:-$(RED)NOT SET$(NC)}"
	@echo "MINIO_SECRET_KEY: $${MINIO_SECRET_KEY:-$(RED)NOT SET$(NC)}"
	@echo "JENKINS_TOKEN: $${JENKINS_TOKEN:-$(RED)NOT SET$(NC)}"
	@echo "GITEA_TOKEN: $${GITEA_TOKEN:-$(RED)NOT SET$(NC)}"
	@echo "GRAFANA_ADMIN_PASSWORD: $${GRAFANA_ADMIN_PASSWORD:-$(RED)NOT SET$(NC)}"

# Validation targets
.PHONY: validate
validate: ## Validate configuration and prerequisites
	@echo -e "$(BLUE)[INFO]$(NC) Validating configuration and prerequisites..."
	@errors=0; \
	if ! command -v kubectl &> /dev/null; then \
		echo -e "$(RED)[ERROR]$(NC) kubectl is not installed"; \
		errors=$$((errors+1)); \
	fi; \
	if ! command -v helm &> /dev/null; then \
		echo -e "$(RED)[ERROR]$(NC) helm is not installed"; \
		errors=$$((errors+1)); \
	fi; \
	if ! command -v docker &> /dev/null; then \
		echo -e "$(RED)[ERROR]$(NC) docker is not installed"; \
		errors=$$((errors+1)); \
	fi; \
	if ! command -v terraform &> /dev/null; then \
		echo -e "$(RED)[ERROR]$(NC) terraform is not installed"; \
		errors=$$((errors+1)); \
	fi; \
	if ! command -v ansible-playbook &> /dev/null; then \
		echo -e "$(RED)[ERROR]$(NC) ansible is not installed"; \
		errors=$$((errors+1)); \
	fi; \
	if [ ! -f $(KUBECONFIG) ]; then \
		echo -e "$(RED)[ERROR]$(NC) kubeconfig not found at $(KUBECONFIG)"; \
		errors=$$((errors+1)); \
	fi; \
	if [ $$errors -eq 0 ]; then \
		echo -e "$(GREEN)[SUCCESS]$(NC) All prerequisites are met"; \
	else \
		echo -e "$(RED)[ERROR]$(NC) $$errors validation errors found"; \
		exit 1; \
	fi

# Quick start target
.PHONY: quickstart
quickstart: validate version bootstrap build deploy ## Quick start: validate, bootstrap, build, and deploy
	@echo -e "$(GREEN)🎉 Happy Speller is ready! 🎉$(NC)"
	@echo ""
	@echo -e "$(BLUE)Access your application:$(NC)"
	@echo "  kubectl -n $(NAMESPACE) port-forward svc/$(APP_NAME) 8080:8080"
	@echo "  Then open: http://localhost:8080"
	@echo ""
	@echo -e "$(BLUE)Useful commands:$(NC)"
	@echo "  make status       - Check application status"
	@echo "  make logs         - View application logs"
	@echo "  make shell        - Get shell access to pod"
	@echo "  make test-integration - Run integration tests"
	@echo ""
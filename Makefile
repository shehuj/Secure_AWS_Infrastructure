# Unified Makefile for Secure AWS Infrastructure
# Automates all operations across Terraform, Ansible, and deployments

.PHONY: help init setup validate test security deploy clean

# Default environment
ENV ?= dev
APP ?= webapp
REGION ?= us-east-1

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help:
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE) Secure AWS Infrastructure - Makefile$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@echo "$(GREEN)Setup & Initialization:$(NC)"
	@echo "  make setup              - Initial setup (install tools, configure)"
	@echo "  make init               - Initialize Terraform and Ansible"
	@echo "  make bootstrap          - Bootstrap S3 backend and DynamoDB"
	@echo ""
	@echo "$(GREEN)Validation & Testing:$(NC)"
	@echo "  make validate           - Validate all configurations"
	@echo "  make test               - Run all tests"
	@echo "  make lint               - Run linters (Terraform, Ansible, Shell)"
	@echo "  make security           - Run security scans"
	@echo ""
	@echo "$(GREEN)Infrastructure (Terraform):$(NC)"
	@echo "  make tf-init            - Initialize Terraform"
	@echo "  make tf-plan            - Plan Terraform changes"
	@echo "  make tf-apply           - Apply Terraform changes"
	@echo "  make tf-destroy         - Destroy Terraform resources"
	@echo "  make tf-fmt             - Format Terraform files"
	@echo ""
	@echo "$(GREEN)Configuration (Ansible):$(NC)"
	@echo "  make ansible-lint       - Lint Ansible playbooks"
	@echo "  make ansible-deploy     - Deploy with Ansible"
	@echo "  make ansible-verify     - Verify Ansible deployment"
	@echo ""
	@echo "$(GREEN)Application Deployment:$(NC)"
	@echo "  make deploy             - Deploy application (blue-green)"
	@echo "  make deploy-wait        - Deploy and wait for completion"
	@echo "  make rollback           - Rollback deployment"
	@echo "  make status             - Check deployment status"
	@echo ""
	@echo "$(GREEN)CI/CD:$(NC)"
	@echo "  make pre-commit-install - Install pre-commit hooks"
	@echo "  make pre-commit-run     - Run pre-commit on all files"
	@echo "  make ci-local           - Run CI checks locally"
	@echo ""
	@echo "$(GREEN)Utilities:$(NC)"
	@echo "  make clean              - Clean temporary files"
	@echo "  make docs               - Generate documentation"
	@echo "  make cost-estimate      - Estimate infrastructure costs"
	@echo ""
	@echo "$(YELLOW)Variables:$(NC)"
	@echo "  ENV=[dev|staging|prod]  - Target environment (default: dev)"
	@echo "  APP=[app-name]          - Application name (default: webapp)"
	@echo "  REGION=[aws-region]     - AWS region (default: us-east-1)"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make setup"
	@echo "  make tf-plan ENV=prod"
	@echo "  make deploy ENV=staging APP=api IMAGE=api:v2.0"
	@echo "  make rollback ENV=prod APP=webapp"

#============================================
# Setup & Initialization
#============================================

setup:
	@echo "$(BLUE)🚀 Setting up development environment...$(NC)"
	@if [ -f "scripts/setup/install-tools.sh" ]; then ./scripts/setup/install-tools.sh; fi
	@make pre-commit-install
	@echo "$(GREEN)✅ Setup complete!$(NC)"

bootstrap:
	@echo "$(BLUE)🔧 Bootstrapping Terraform backend...$(NC)"
	@if [ -f "scripts/bootstrap.sh" ]; then ./scripts/bootstrap.sh; fi

init: tf-init
	@echo "$(GREEN)✅ Initialization complete!$(NC)"

#============================================
# Terraform Operations
#============================================

tf-init:
	@echo "$(BLUE)🔧 Initializing Terraform...$(NC)"
	cd terraform && terraform init -upgrade

tf-fmt:
	@echo "$(BLUE)🎨 Formatting Terraform files...$(NC)"
	cd terraform && terraform fmt -recursive

tf-validate: tf-init
	@echo "$(BLUE)✓ Validating Terraform...$(NC)"
	cd terraform && terraform validate

tf-plan: tf-init
	@echo "$(BLUE)📋 Planning Terraform changes for $(ENV)...$(NC)"
	cd terraform && terraform plan -var="environment=$(ENV)" -out=$(ENV).tfplan

tf-apply: tf-plan
	@echo "$(YELLOW)⚠️  Applying Terraform changes for $(ENV)...$(NC)"
	cd terraform && terraform apply $(ENV).tfplan
	@echo "$(GREEN)✅ Terraform apply complete!$(NC)"

tf-destroy:
	@echo "$(RED)⚠️  WARNING: This will destroy infrastructure!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	cd terraform && terraform destroy -var="environment=$(ENV)"

tf-output:
	@cd terraform && terraform output -json

#============================================
# Ansible Operations
#============================================

ansible-lint:
	@echo "$(BLUE)🔍 Linting Ansible playbooks...$(NC)"
	cd ansible && ansible-lint playbooks/*.yml --profile production

ansible-syntax:
	@echo "$(BLUE)✓ Checking Ansible syntax...$(NC)"
	cd ansible && for playbook in playbooks/*.yml; do \
		echo "Checking $$playbook..."; \
		ansible-playbook $$playbook --syntax-check; \
	done

ansible-deploy:
	@echo "$(BLUE)🚀 Deploying with Ansible to $(ENV)...$(NC)"
	cd ansible && ansible-playbook playbooks/webserver.yml \
		-i inventories/$(ENV)/hosts.yml \
		-e "app_environment=$(ENV)" \
		--diff

ansible-check:
	@echo "$(BLUE)🔍 Running Ansible in check mode...$(NC)"
	cd ansible && ansible-playbook playbooks/webserver.yml \
		-i inventories/$(ENV)/hosts.yml \
		-e "app_environment=$(ENV)" \
		--check --diff

ansible-verify:
	@echo "$(BLUE)✓ Verifying Ansible deployment...$(NC)"
	@if [ -f "ansible/playbooks/verify.yml" ]; then \
		cd ansible && ansible-playbook playbooks/verify.yml -i inventories/$(ENV)/hosts.yml; \
	else \
		echo "$(YELLOW)No verify playbook found$(NC)"; \
	fi

#============================================
# Application Deployment (Blue-Green)
#============================================

deploy:
	@echo "$(BLUE)🚀 Deploying $(APP) to $(ENV)...$(NC)"
	@if [ -z "$(IMAGE)" ]; then \
		echo "$(RED)Error: IMAGE variable required$(NC)"; \
		echo "Usage: make deploy IMAGE=myapp:v1.0 ENV=prod"; \
		exit 1; \
	fi
	./scripts/blue-green/deploy.sh -e $(ENV) -a $(APP) -i $(IMAGE) -r $(REGION)

deploy-wait:
	@echo "$(BLUE)🚀 Deploying $(APP) to $(ENV) and waiting...$(NC)"
	@if [ -z "$(IMAGE)" ]; then \
		echo "$(RED)Error: IMAGE variable required$(NC)"; \
		exit 1; \
	fi
	./scripts/blue-green/deploy.sh -e $(ENV) -a $(APP) -i $(IMAGE) -r $(REGION) --wait

rollback:
	@echo "$(YELLOW)⏪ Rolling back $(APP) in $(ENV)...$(NC)"
	./scripts/blue-green/rollback.sh -e $(ENV) -a $(APP) -r $(REGION)

status:
	@./scripts/blue-green/status.sh -e $(ENV) -a $(APP) -r $(REGION)

watch:
	@./scripts/blue-green/status.sh -e $(ENV) -a $(APP) -r $(REGION) --watch

#============================================
# Validation & Testing
#============================================

validate: tf-validate ansible-lint
	@echo "$(GREEN)✅ All validations passed!$(NC)"

format: tf-fmt
	@echo "$(BLUE)🎨 Formatting code...$(NC)"
	@cd ansible && ansible-lint playbooks/ --fix || true
	@echo "$(GREEN)✅ Formatting complete!$(NC)"

lint: tf-fmt ansible-lint
	@echo "$(BLUE)🔍 Running ShellCheck...$(NC)"
	@find scripts -name "*.sh" -type f -exec shellcheck {} + || true
	@echo "$(GREEN)✅ All linting complete!$(NC)"

test: validate
	@echo "$(BLUE)🧪 Running tests...$(NC)"
	@if [ -f "scripts/test-idempotency.sh" ]; then ./scripts/test-idempotency.sh; fi
	@echo "$(GREEN)✅ All tests passed!$(NC)"

idempotency-test:
	@echo "$(BLUE)🔁 Running idempotency tests...$(NC)"
	@if [ -f "scripts/test-idempotency.sh" ]; then ./scripts/test-idempotency.sh; fi

#============================================
# Security
#============================================

security: security-terraform security-ansible security-secrets
	@echo "$(GREEN)✅ Security scans complete!$(NC)"

security-terraform:
	@echo "$(BLUE)🔒 Running Terraform security scans...$(NC)"
	@if command -v checkov >/dev/null 2>&1; then \
		checkov -d terraform/ --framework terraform; \
	else \
		echo "$(YELLOW)⚠️  Checkov not installed, skipping$(NC)"; \
	fi
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec terraform/; \
	else \
		echo "$(YELLOW)⚠️  tfsec not installed, skipping$(NC)"; \
	fi

security-ansible:
	@echo "$(BLUE)🔒 Running Ansible security checks...$(NC)"
	cd ansible && ansible-lint playbooks/*.yml --profile production

security-secrets:
	@echo "$(BLUE)🔒 Scanning for secrets...$(NC)"
	@if command -v detect-secrets >/dev/null 2>&1; then \
		detect-secrets scan --baseline .secrets.baseline; \
	else \
		echo "$(YELLOW)⚠️  detect-secrets not installed, skipping$(NC)"; \
	fi

security-scan: security
	@echo "$(GREEN)✅ Security scan complete!$(NC)"

#============================================
# Pre-commit
#============================================

pre-commit-install:
	@echo "$(BLUE)🔧 Installing pre-commit hooks...$(NC)"
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		echo "$(YELLOW)Installing pre-commit...$(NC)"; \
		pip install pre-commit; \
	fi
	pre-commit install
	pre-commit install --hook-type commit-msg
	@echo "$(GREEN)✅ Pre-commit hooks installed!$(NC)"

pre-commit-run:
	@echo "$(BLUE)🔍 Running pre-commit on all files...$(NC)"
	pre-commit run --all-files

#============================================
# CI/CD
#============================================

ci-local: lint test security
	@echo "$(GREEN)✅ Local CI checks passed!$(NC)"

#============================================
# Utilities
#============================================

clean:
	@echo "$(BLUE)🧹 Cleaning temporary files...$(NC)"
	find . -name "*.tfplan" -delete
	find . -name "*.log" -delete
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	rm -f /tmp/appspec-*.json
	rm -f /tmp/rollback-appspec.json
	@echo "$(GREEN)✅ Cleanup complete!$(NC)"

cost-estimate:
	@echo "$(BLUE)💰 Estimating infrastructure costs...$(NC)"
	@if command -v infracost >/dev/null 2>&1; then \
		cd terraform && infracost breakdown --path .; \
	else \
		echo "$(YELLOW)⚠️  Infracost not installed$(NC)"; \
		echo "Install with: brew install infracost"; \
	fi

docs:
	@echo "$(BLUE)📚 Documentation available:$(NC)"
	@echo "  - README.md"
	@echo "  - docs/DEPLOYMENT_GUIDE.md"
	@echo "  - docs/BLUE_GREEN_DEPLOYMENT.md"
	@echo "  - docs/BLUE_GREEN_QUICKSTART.md"

#============================================
# Quick Workflows
#============================================

quick-deploy: init tf-plan tf-apply ansible-deploy
	@echo "$(GREEN)✅ Quick deployment completed!$(NC)"

full-deploy: validate test init tf-apply ansible-deploy
	@echo "$(GREEN)✅ Full deployment completed!$(NC)"

dev-setup: setup
	@echo "$(BLUE)🔧 Setting up dev environment...$(NC)"
	@make tf-apply ENV=dev
	@make ansible-deploy ENV=dev
	@echo "$(GREEN)✅ Dev environment ready!$(NC)"

#============================================
# Multi-Environment Deployment
#============================================

deploy-all-envs:
	@echo "$(BLUE)🚀 Deploying to all environments...$(NC)"
	@make tf-apply ENV=dev && make ansible-deploy ENV=dev
	@echo "$(GREEN)Dev complete. Proceeding to staging...$(NC)"
	@make tf-apply ENV=staging && make ansible-deploy ENV=staging
	@echo "$(GREEN)Staging complete. Production requires manual approval.$(NC)"

#============================================
# Monitoring
#============================================

logs:
	@echo "$(BLUE)📋 Fetching logs for $(APP) in $(ENV)...$(NC)"
	@aws logs tail /ecs/$(ENV)/$(APP) --follow --region $(REGION) 2>/dev/null || echo "No logs found"

info:
	@echo "$(BLUE)ℹ️  Infrastructure Information$(NC)"
	@echo "Environment: $(ENV)"
	@echo "Application: $(APP)"
	@echo "Region: $(REGION)"

version:
	@echo "$(BLUE)Tool Versions:$(NC)"
	@echo "Terraform: $$(terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo 'not installed')"
	@echo "Ansible: $$(ansible --version 2>/dev/null | head -n1 || echo 'not installed')"
	@echo "AWS CLI: $$(aws --version 2>/dev/null || echo 'not installed')"
	@echo "Pre-commit: $$(pre-commit --version 2>/dev/null || echo 'not installed')"

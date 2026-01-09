.PHONY: help init plan apply destroy validate format test clean bootstrap ansible-deploy idempotency-test

# Default target
help:
	@echo "Secure AWS Infrastructure - Makefile Commands"
	@echo ""
	@echo "Infrastructure Management:"
	@echo "  make bootstrap          - Bootstrap S3 backend and DynamoDB table"
	@echo "  make init              - Initialize Terraform"
	@echo "  make plan              - Run Terraform plan"
	@echo "  make apply             - Apply Terraform changes"
	@echo "  make destroy           - Destroy all infrastructure"
	@echo ""
	@echo "Validation & Testing:"
	@echo "  make validate          - Validate Terraform configuration"
	@echo "  make format            - Format Terraform and Ansible files"
	@echo "  make test              - Run all tests"
	@echo "  make idempotency-test  - Test infrastructure idempotency"
	@echo "  make security-scan     - Run security scans (tfsec, checkov)"
	@echo ""
	@echo "Configuration Management:"
	@echo "  make ansible-deploy    - Deploy configuration with Ansible"
	@echo "  make ansible-check     - Run Ansible in check mode"
	@echo "  make ansible-lint      - Lint Ansible playbooks"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean             - Clean temporary files"
	@echo "  make docs              - Generate documentation"

# Bootstrap backend infrastructure
bootstrap:
	@echo "Bootstrapping Terraform backend..."
	@./scripts/bootstrap.sh

# Terraform commands
init:
	@echo "Initializing Terraform..."
	@cd terraform && terraform init -upgrade

plan:
	@echo "Running Terraform plan..."
	@cd terraform && terraform plan -out=tfplan

apply:
	@echo "Applying Terraform changes..."
	@cd terraform && terraform apply tfplan

destroy:
	@echo "Destroying infrastructure..."
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform && terraform destroy; \
	fi

# Validation
validate:
	@echo "Validating Terraform configuration..."
	@cd terraform && terraform validate
	@echo "Validating Ansible playbooks..."
	@cd ansible && ansible-playbook playbooks/webserver.yml --syntax-check

format:
	@echo "Formatting Terraform files..."
	@cd terraform && terraform fmt -recursive
	@echo "Checking Ansible formatting..."
	@cd ansible && ansible-lint playbooks/ --fix || true

# Testing
test: validate idempotency-test security-scan
	@echo "All tests completed"

idempotency-test:
	@echo "Running idempotency tests..."
	@./scripts/test-idempotency.sh

security-scan:
	@echo "Running security scans..."
	@which tfsec > /dev/null && cd terraform && tfsec . || echo "tfsec not installed"
	@which checkov > /dev/null && checkov -d terraform/ || echo "checkov not installed"

# Ansible commands
ansible-deploy:
	@echo "Deploying with Ansible..."
	@cd ansible && ansible-playbook playbooks/webserver.yml

ansible-check:
	@echo "Running Ansible in check mode..."
	@cd ansible && ansible-playbook playbooks/webserver.yml --check --diff

ansible-lint:
	@echo "Linting Ansible playbooks..."
	@which ansible-lint > /dev/null && cd ansible && ansible-lint playbooks/ || echo "ansible-lint not installed"

# Utilities
clean:
	@echo "Cleaning temporary files..."
	@find . -type f -name "*.tfplan" -delete
	@find . -type f -name "*.log" -delete
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name ".terraform.lock.hcl" -delete
	@echo "Clean complete"

docs:
	@echo "Documentation available in:"
	@echo "  - README.md"
	@echo "  - docs/DEPLOYMENT_GUIDE.md"
	@echo "  - docs/CHANGES.md"

# Quick deployment workflow
quick-deploy: init plan apply ansible-deploy
	@echo "Quick deployment completed"

# Full deployment with validation
full-deploy: validate test init plan apply ansible-deploy idempotency-test
	@echo "Full deployment completed"

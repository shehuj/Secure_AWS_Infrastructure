# Makefile for Blue-Green Deployments
# Simplifies common deployment operations

.PHONY: help deploy rollback status test clean

# Default environment and app
ENV ?= prod
APP ?= webapp
IMAGE ?= nginx:latest
REGION ?= us-east-1

help:
	@echo "Blue-Green Deployment Commands"
	@echo ""
	@echo "Usage: make [target] ENV=<env> APP=<app> IMAGE=<image>"
	@echo ""
	@echo "Targets:"
	@echo "  deploy       - Deploy new version"
	@echo "  deploy-wait  - Deploy and wait for completion"
	@echo "  rollback     - Rollback to previous version"
	@echo "  status       - Check deployment status"
	@echo "  watch        - Watch deployment progress"
	@echo "  test         - Test green environment"
	@echo "  clean        - Clean up temporary files"
	@echo ""
	@echo "Variables:"
	@echo "  ENV     - Environment (default: prod)"
	@echo "  APP     - Application name (default: webapp)"
	@echo "  IMAGE   - Docker image (default: nginx:latest)"
	@echo "  REGION  - AWS region (default: us-east-1)"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy APP=api IMAGE=myapi:v1.5.0"
	@echo "  make deploy-wait ENV=staging APP=webapp IMAGE=webapp:latest"
	@echo "  make rollback ENV=prod APP=api"
	@echo "  make watch ENV=prod APP=webapp"

deploy:
	@echo "Deploying $(IMAGE) to $(ENV)/$(APP)..."
	@./deploy.sh -e $(ENV) -a $(APP) -i $(IMAGE) -r $(REGION)

deploy-wait:
	@echo "Deploying $(IMAGE) to $(ENV)/$(APP) and waiting..."
	@./deploy.sh -e $(ENV) -a $(APP) -i $(IMAGE) -r $(REGION) --wait

rollback:
	@echo "Rolling back $(ENV)/$(APP)..."
	@./rollback.sh -e $(ENV) -a $(APP) -r $(REGION)

status:
	@./status.sh -e $(ENV) -a $(APP) -r $(REGION)

watch:
	@./status.sh -e $(ENV) -a $(APP) -r $(REGION) --watch

test:
	@echo "Testing green environment for $(ENV)/$(APP)..."
	@ALB_DNS=$$(aws elbv2 describe-load-balancers \
		--names $(ENV)-$(APP)-alb \
		--region $(REGION) \
		--query 'LoadBalancers[0].DNSName' \
		--output text 2>/dev/null); \
	if [ -n "$$ALB_DNS" ]; then \
		echo "Testing: https://$$ALB_DNS:8443"; \
		curl -k -f https://$$ALB_DNS:8443/health || echo "Health check failed!"; \
	else \
		echo "ALB not found!"; \
	fi

clean:
	@echo "Cleaning up temporary files..."
	@rm -f /tmp/appspec-*.json
	@rm -f /tmp/rollback-appspec.json
	@echo "Clean complete"

# Quick commands
.PHONY: prod staging dev

prod:
	@$(MAKE) status ENV=prod

staging:
	@$(MAKE) status ENV=staging

dev:
	@$(MAKE) status ENV=dev

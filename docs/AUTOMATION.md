# Automation Guide

Complete automation setup for zero-manual-effort infrastructure deployment and management.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [CI/CD Pipelines](#cicd-pipelines)
4. [Pre-commit Hooks](#pre-commit-hooks)
5. [Automated Testing](#automated-testing)
6. [Security Automation](#security-automation)
7. [Monitoring & Alerting](#monitoring--alerting)
8. [Deployment Orchestration](#deployment-orchestration)
9. [Makefile Reference](#makefile-reference)
10. [Troubleshooting](#troubleshooting)

---

## Overview

This repository implements **fully automated infrastructure deployment** with:

- ✅ **Continuous Integration/Deployment** - GitHub Actions workflows
- ✅ **Pre-commit Validation** - Automated code quality checks
- ✅ **Security Scanning** - Multiple security tools integrated
- ✅ **Blue-Green Deployments** - Zero-downtime releases
- ✅ **Automated Testing** - Unit, integration, and idempotency tests
- ✅ **Monitoring** - Automated health checks and metrics
- ✅ **Multi-Environment** - Dev, Staging, Production pipelines

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Developer Workflow                      │
└───────────────┬─────────────────────────────────────────────┘
                │
                ↓
        ┌──────────────┐
        │  Git Commit   │
        └──────┬───────┘
               │
               ↓
    ┌──────────────────┐
    │  Pre-commit      │  ← Terraform fmt, ansible-lint, security
    │  Hooks           │
    └──────┬───────────┘
           │
           ↓
    ┌──────────────────┐
    │  Git Push         │
    └──────┬───────────┘
           │
           ↓
┌──────────────────────────────────────────────────────┐
│           GitHub Actions CI/CD Pipeline               │
├──────────────────────────────────────────────────────┤
│  1. Validation     → Terraform, Ansible, YAML        │
│  2. Security Scan  → Checkov, tfsec, TruffleHog      │
│  3. Build          → Docker image, ECR push          │
│  4. Test           → Unit, Integration               │
│  5. Deploy Dev     → Auto-deploy to dev              │
│  6. Deploy Staging → Auto-deploy to staging          │
│  7. Deploy Prod    → Manual approval required        │
└────────────┬─────────────────────────────────────────┘
             │
             ↓
    ┌────────────────┐
    │  Infrastructure │  ← Terraform applies changes
    │  Provisioned    │
    └────────┬───────┘
             │
             ↓
    ┌────────────────┐
    │  Configuration  │  ← Ansible configures servers
    │  Applied        │
    └────────┬───────┘
             │
             ↓
    ┌────────────────┐
    │  Application    │  ← Blue-Green deployment
    │  Deployed       │
    └────────┬───────┘
             │
             ↓
    ┌────────────────┐
    │  Health Check   │  ← Automated validation
    │  & Monitoring   │
    └────────────────┘
```

---

## Quick Start

### 1. Initial Setup

```bash
# Clone repository
git clone <repository-url>
cd Secure_AWS_Infrastructure

# Run setup (installs all tools)
make setup

# Configure AWS credentials
aws configure
```

### 2. Install Pre-commit Hooks

```bash
# Install hooks
make pre-commit-install

# Test hooks
make pre-commit-run
```

### 3. Deploy to Development

```bash
# Full automated deployment
make dev-setup

# Or step-by-step
make tf-init
make tf-apply ENV=dev
make ansible-deploy ENV=dev
```

### 4. Deploy Application

```bash
# Deploy with blue-green
make deploy-wait ENV=dev IMAGE=webapp:v1.0 APP=webapp

# Monitor deployment
make watch ENV=dev APP=webapp
```

---

## CI/CD Pipelines

### GitHub Actions Workflows

#### 1. Terraform CI/CD (`terraform-ci-cd.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests
- Manual workflow dispatch

**Jobs:**
- `terraform-validate` - Format check, validation, TFLint, Checkov
- `terraform-plan` - Generate plans for all environments
- `terraform-apply` - Auto-apply to dev/staging, manual for prod

**Environment Variables:**
```yaml
TF_VERSION: '1.7.0'
AWS_REGION: 'us-east-1'
```

**Secrets Required:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_PROD_ROLE_ARN` (for production)
- `SLACK_WEBHOOK` (optional, for notifications)

**Usage:**
```bash
# Automatic on push to main
git push origin main

# Manual deployment to production
gh workflow run terraform-ci-cd.yml -f environment=prod -f action=apply
```

#### 2. Ansible CI/CD (`ansible-ci-cd.yml`)

**Triggers:**
- Push to ansible/ directory
- Pull requests affecting ansible/
- Manual workflow dispatch

**Jobs:**
- `ansible-lint` - Linting with production profile
- `ansible-test` - Molecule tests
- `ansible-deploy-dev` - Auto-deploy to dev
- `ansible-deploy-staging` - Auto-deploy to staging
- `ansible-deploy-prod` - Manual deploy with approval

**Usage:**
```bash
# Automatic on push
git push origin main

# Manual production deployment
gh workflow run ansible-ci-cd.yml -f environment=prod -f playbook=webserver.yml
```

#### 3. Blue-Green Deployment (`blue-green-deployment.yml`)

**Triggers:**
- Push to `main` (app code changes)
- Manual workflow dispatch

**Jobs:**
- `build-and-push` - Build Docker image, push to ECR, scan with Trivy
- `deploy-dev` - Auto-deploy to dev
- `deploy-staging` - Auto-deploy to staging with smoke tests
- `deploy-prod` - Manual deploy with approval and rollback on failure

**Features:**
- Automated Docker builds
- Container vulnerability scanning
- Smoke tests after deployment
- Automatic rollback on failure
- GitHub release creation

**Usage:**
```bash
# Automatic on push
git push origin main

# Manual production deployment
gh workflow run blue-green-deployment.yml \
  -f environment=prod \
  -f image_tag=v2.0 \
  -f wait_for_deployment=true
```

#### 4. Security Scanning (`security-scan.yml`)

**Triggers:**
- Push to any branch
- Pull requests
- Scheduled daily at 2 AM UTC
- Manual workflow dispatch

**Scans:**
- Secret scanning (TruffleHog, Gitleaks)
- Terraform security (Checkov, tfsec)
- Ansible security (ansible-lint)
- Dependency scanning (Snyk, OWASP)
- SAST scanning (CodeQL, SonarCloud)
- Container scanning (Trivy)

**Secrets Required:**
- `SNYK_TOKEN`
- `SONAR_TOKEN`

**Usage:**
```bash
# Runs automatically on schedule
# Manual run:
gh workflow run security-scan.yml
```

#### 5. PR Validation (`pr-validation.yml`)

**Triggers:**
- Pull request opened/updated

**Checks:**
- Auto-labeling
- PR size validation
- Commit message format (conventional commits)
- Code validation (Terraform, Ansible)
- Documentation checks
- Security checks
- Script testing (ShellCheck)

#### 6. Dependency Updates (`dependency-update.yml`)

**Triggers:**
- Scheduled weekly on Mondays
- Manual workflow dispatch

**Updates:**
- Terraform provider versions
- Ansible collections
- GitHub Actions versions

**Features:**
- Automatic PRs for updates
- Dependabot integration
- Auto-merge for minor updates

---

## Pre-commit Hooks

### Configuration

Pre-commit hooks are defined in `.pre-commit-config.yaml`.

### Installed Hooks

#### General Checks
- Trailing whitespace removal
- End-of-file fixer
- YAML/JSON validation
- Large file detection
- Merge conflict detection
- Private key detection

#### Terraform
- `terraform_fmt` - Format code
- `terraform_validate` - Validate configuration
- `terraform_docs` - Generate documentation
- `terraform_tflint` - Linting
- `terraform_checkov` - Security scanning
- `terraform_tfsec` - Security scanning

#### Ansible
- `ansible-lint` - Linting with production profile

#### Security
- `detect-secrets` - Secret detection
- `trufflehog` - Secret scanning

#### Custom Hooks
- `terraform-cost-estimation` - Cost estimates
- `ansible-syntax-check` - Syntax validation
- `validate-infrastructure` - Configuration consistency
- `check-sensitive-data` - Sensitive data detection

### Usage

```bash
# Install hooks
make pre-commit-install

# Run manually on all files
make pre-commit-run

# Run on staged files only
pre-commit run

# Update hooks
pre-commit autoupdate

# Skip hooks (not recommended)
git commit --no-verify
```

### Custom Hook Scripts

Located in `scripts/hooks/`:

1. **cost-estimate.sh** - Estimates infrastructure costs using Infracost
2. **ansible-syntax-check.sh** - Validates Ansible playbooks
3. **validate-infrastructure.sh** - Checks configuration consistency
4. **check-sensitive-data.sh** - Prevents committing sensitive data

---

## Automated Testing

### Test Scripts

#### 1. Unit Tests (`scripts/test/run-tests.sh`)

Validates all code without deploying:

```bash
# Run all tests
make test

# Or directly
./scripts/test/run-tests.sh
```

**Tests:**
- Terraform validation
- Terraform format check
- Ansible syntax check
- Ansible lint
- ShellCheck for all scripts
- YAML lint
- Secret detection
- Required files check
- Blue-green scripts validation

#### 2. Integration Tests (`scripts/test/integration-test.sh`)

Tests deployed infrastructure:

```bash
# Test dev environment
./scripts/test/integration-test.sh dev

# Test staging
./scripts/test/integration-test.sh staging
```

**Checks:**
- AWS connectivity
- ECS cluster status
- ALB health
- Target group health
- CodeDeploy application
- CloudWatch log groups
- Security groups
- IAM roles

#### 3. Idempotency Tests (`scripts/test-idempotency.sh`)

Tests that infrastructure can be applied multiple times without changes:

```bash
make idempotency-test
```

### Test Results

Tests output colored results:
- 🟢 **Green** - Test passed
- 🟡 **Yellow** - Warning
- 🔴 **Red** - Test failed

---

## Security Automation

### Security Scanning Tools

#### 1. Terraform Security

**Tools:**
- **Checkov** - Policy-as-code scanner
- **tfsec** - Static analysis
- **TFLint** - Linting with AWS rules

**Run:**
```bash
make security-terraform
```

#### 2. Ansible Security

**Tools:**
- **ansible-lint** - Production profile

**Run:**
```bash
make security-ansible
```

#### 3. Secret Scanning

**Tools:**
- **detect-secrets** - Secret detection
- **TruffleHog** - Git history scanning
- **Gitleaks** - Secret leaks

**Run:**
```bash
make security-secrets
```

#### 4. Container Security

**Tools:**
- **Trivy** - Container vulnerability scanner

**Run:**
```bash
# In CI/CD pipeline
# Scans images after build
```

### Security Baseline

`.secrets.baseline` file tracks known false positives.

**Update baseline:**
```bash
detect-secrets scan > .secrets.baseline
```

### Security Best Practices

1. **Never commit secrets** - Use AWS Secrets Manager or Parameter Store
2. **Enable MFA** - For AWS accounts
3. **Use least privilege** - IAM policies
4. **Enable encryption** - At rest and in transit
5. **Regular scanning** - Daily automated scans
6. **Dependency updates** - Weekly automated updates

---

## Monitoring & Alerting

### Health Checks

#### Automated Health Check (`scripts/monitoring/health-check.sh`)

Comprehensive health validation:

```bash
# Check application health
./scripts/monitoring/health-check.sh -e prod -a webapp
```

**Checks:**
1. ECS Service (30 points)
2. Target Groups (25 points)
3. ALB (20 points)
4. Recent Deployments (15 points)
5. CloudWatch Alarms (10 points)

**Health Scores:**
- 90-100: HEALTHY ✓
- 70-89: DEGRADED !
- 0-69: UNHEALTHY ✗

#### Metrics Collection (`scripts/monitoring/get-metrics.sh`)

Fetches CloudWatch metrics:

```bash
# Get metrics for last hour
./scripts/monitoring/get-metrics.sh -e prod -a webapp

# Custom time period (in minutes)
./scripts/monitoring/get-metrics.sh -e prod -a webapp -p 120
```

**Metrics:**
- CPU Utilization
- Memory Utilization
- Running Task Count
- Request Count
- Response Time
- 2XX/5XX Response Counts
- Error Rate

### Log Monitoring

```bash
# Tail logs
make logs ENV=prod APP=webapp

# Or directly
aws logs tail /ecs/prod/webapp --follow
```

### Setting Up CloudWatch Alarms

Add to Terraform:

```hcl
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment}-${var.app_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main.name
  }
}
```

---

## Deployment Orchestration

### Full Deployment Script

Complete end-to-end deployment:

```bash
# Deploy to dev
./scripts/deploy/full-deployment.sh -e dev

# Deploy to prod with image
./scripts/deploy/full-deployment.sh -e prod -i webapp:v2.0

# Skip tests (not recommended)
./scripts/deploy/full-deployment.sh -e dev -s

# Auto-approve all prompts
./scripts/deploy/full-deployment.sh -e dev -y
```

**Steps:**
1. Pre-flight checks (tools, credentials)
2. Validation & testing
3. Terraform infrastructure provisioning
4. Ansible configuration management
5. Application deployment (blue-green)
6. Integration tests
7. Health check

### Multi-Environment Deployment

```bash
# Deploy to all environments
make deploy-all-envs

# This deploys:
# 1. Dev (automatic)
# 2. Staging (automatic after dev)
# 3. Prod (requires manual confirmation)
```

### Blue-Green Deployment

```bash
# Deploy new version
make deploy ENV=prod IMAGE=webapp:v2.0 APP=webapp

# Deploy and wait for completion
make deploy-wait ENV=prod IMAGE=webapp:v2.0 APP=webapp

# Monitor deployment
make watch ENV=prod APP=webapp

# Rollback if needed
make rollback ENV=prod APP=webapp
```

---

## Makefile Reference

### Setup & Initialization

```bash
make setup              # Install all tools
make init               # Initialize Terraform
make bootstrap          # Bootstrap S3 backend
```

### Validation & Testing

```bash
make validate           # Validate all configurations
make test               # Run all tests
make lint               # Run all linters
make security           # Run security scans
make idempotency-test   # Test idempotency
```

### Terraform Operations

```bash
make tf-init            # Initialize Terraform
make tf-plan ENV=dev    # Plan changes
make tf-apply ENV=dev   # Apply changes
make tf-destroy ENV=dev # Destroy infrastructure
make tf-fmt             # Format Terraform files
make tf-validate        # Validate Terraform
```

### Ansible Operations

```bash
make ansible-lint                  # Lint playbooks
make ansible-syntax                # Check syntax
make ansible-deploy ENV=dev        # Deploy configuration
make ansible-check ENV=dev         # Run in check mode
make ansible-verify ENV=dev        # Verify deployment
```

### Application Deployment

```bash
make deploy ENV=dev IMAGE=webapp:v1.0        # Deploy
make deploy-wait ENV=dev IMAGE=webapp:v1.0   # Deploy and wait
make rollback ENV=dev APP=webapp             # Rollback
make status ENV=dev APP=webapp               # Check status
make watch ENV=dev APP=webapp                # Watch deployment
```

### CI/CD

```bash
make pre-commit-install  # Install hooks
make pre-commit-run      # Run hooks on all files
make ci-local            # Run CI checks locally
```

### Monitoring

```bash
make logs ENV=prod APP=webapp    # Tail logs
make info                        # Show environment info
make version                     # Show tool versions
```

### Utilities

```bash
make clean             # Clean temporary files
make docs              # Show documentation
make cost-estimate     # Estimate costs
```

### Quick Workflows

```bash
make quick-deploy      # Quick deployment (init + plan + apply + ansible)
make full-deploy       # Full deployment (validate + test + deploy)
make dev-setup         # Setup dev environment
```

### Variables

All Makefile targets support these variables:

```bash
ENV=<environment>    # dev, staging, prod (default: dev)
APP=<app-name>       # Application name (default: webapp)
REGION=<aws-region>  # AWS region (default: us-east-1)
IMAGE=<image:tag>    # Docker image (required for deploy)
```

**Examples:**

```bash
# Deploy to staging
make tf-apply ENV=staging

# Deploy different app
make deploy ENV=prod APP=api IMAGE=api:v2.0

# Use different region
make status ENV=prod APP=webapp REGION=us-west-2
```

---

## Troubleshooting

### Common Issues

#### 1. Pre-commit Hooks Failing

**Problem:** Hooks fail on commit

**Solution:**
```bash
# Run manually to see errors
make pre-commit-run

# Fix issues and commit again
git add .
git commit -m "fix: resolve issues"

# Skip hooks if urgent (not recommended)
git commit --no-verify
```

#### 2. Terraform Plan Shows Changes on Rerun

**Problem:** Terraform always shows changes

**Solution:**
```bash
# Check for idempotency issues
make idempotency-test

# Common causes:
# - timestamp attributes
# - random values without lifecycle rules
# - attributes not in state
```

#### 3. Ansible Lint Errors

**Problem:** ansible-lint fails

**Solution:**
```bash
# Run lint with details
cd ansible && ansible-lint playbooks/*.yml --profile production

# Auto-fix some issues
cd ansible && ansible-lint playbooks/*.yml --fix

# Check specific rules
cd ansible && ansible-lint playbooks/*.yml --list-rules
```

#### 4. Blue-Green Deployment Stuck

**Problem:** Deployment not progressing

**Solution:**
```bash
# Check status
make status ENV=prod APP=webapp

# Check ECS events
aws ecs describe-services \
  --cluster prod-webapp-cluster \
  --services prod-webapp-service \
  --query 'services[0].events[0:5]'

# Check CodeDeploy
aws deploy get-deployment --deployment-id <deployment-id>

# Rollback if needed
make rollback ENV=prod APP=webapp
```

#### 5. AWS Credentials Issues

**Problem:** Cannot authenticate to AWS

**Solution:**
```bash
# Check credentials
aws sts get-caller-identity

# Configure credentials
aws configure

# Use different profile
export AWS_PROFILE=my-profile
```

#### 6. Tool Not Found

**Problem:** Command not found errors

**Solution:**
```bash
# Install all tools
make setup

# Or install specific tool
# - terraform: brew install terraform
# - ansible: brew install ansible
# - aws: brew install awscli
```

### Debug Mode

Enable debug output:

```bash
# Terraform
export TF_LOG=DEBUG

# Ansible
ansible-playbook playbook.yml -vvv

# AWS CLI
aws --debug <command>
```

### Getting Help

1. **Check documentation:** `make docs`
2. **Run health check:** `./scripts/monitoring/health-check.sh -e <env> -a <app>`
3. **Check logs:** `make logs ENV=<env> APP=<app>`
4. **Review GitHub Actions:** Check workflow runs
5. **Open an issue:** GitHub repository

---

## Best Practices

### Development Workflow

1. **Create feature branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make changes**
   - Edit Terraform/Ansible files
   - Pre-commit hooks run automatically

3. **Test locally**
   ```bash
   make ci-local
   ```

4. **Create PR**
   - PR validation runs automatically
   - Review and address feedback

5. **Merge to main**
   - Auto-deploys to dev and staging
   - Manual approval for production

### Production Deployments

1. **Always test in dev/staging first**
2. **Review Terraform plans carefully**
3. **Have rollback plan ready**
4. **Monitor during deployment**
5. **Verify health after deployment**

### Security

1. **Never commit secrets**
2. **Enable all security scans**
3. **Review scan results**
4. **Keep dependencies updated**
5. **Use least privilege IAM**

### Monitoring

1. **Set up CloudWatch alarms**
2. **Monitor health scores**
3. **Review logs regularly**
4. **Track metrics over time**
5. **Set up SNS notifications**

---

## Additional Resources

- [Blue-Green Deployment Guide](./BLUE_GREEN_DEPLOYMENT.md)
- [Blue-Green Quick Start](./BLUE_GREEN_QUICKSTART.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [Terraform Modules](../terraform/modules/)
- [Ansible Playbooks](../ansible/playbooks/)
- [CI/CD Workflows](../.github/workflows/)

---

**Last Updated:** 2026-01-11
**Version:** 2.0.0

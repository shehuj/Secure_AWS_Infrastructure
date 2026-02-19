# Secure AWS Infrastructure

**Production-ready, fully automated AWS infrastructure with zero-downtime deployments**

A comprehensive Infrastructure-as-Code (IaC) solution combining Terraform, Ansible, and GitHub Actions to deploy secure, scalable AWS infrastructure with enterprise-grade monitoring, security scanning, and automated deployments.

![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
![Terraform](https://img.shields.io/badge/terraform-1.7+-purple.svg)
![AWS](https://img.shields.io/badge/AWS-Cloud-orange.svg)

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Infrastructure Components](#infrastructure-components)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security](#security)
- [Monitoring & Analytics](#monitoring--analytics)
- [Blue-Green Deployments](#blue-green-deployments)
- [Cost Estimation](#cost-estimation)
- [Troubleshooting](#troubleshooting)
- [Makefile Commands](#makefile-commands)
- [Contributing](#contributing)

---

## Features

### 🚀 Automation & Deployment
- **Fully Automated CI/CD** — 6 GitHub Actions workflows for zero-manual-effort deployment
- **Idempotent Infrastructure** — Safe to run repeatedly without side effects (Terraform state locking + Ansible idempotent modules)
- **Zero-Downtime Deployments** — Blue-green deployment strategy with instant rollback capability
- **Pre-Commit Validation** — 20+ automated checks (Terraform, Ansible, security, linting) before every commit
- **Multi-Environment Support** — Separate dev/staging/production with environment-specific configurations

### 🔒 Security & Compliance
- **8 Security Scanning Tools** — Always-on: TruffleHog, Gitleaks, Checkov, tfsec, Trivy, ansible-lint, detect-secrets, CodeQL
- **GitHub OIDC Authentication** — Keyless AWS access (no long-lived credentials)
- **Encrypted Everything** — KMS encryption for all data at rest and in transit
- **Least Privilege IAM** — Granular permissions per service with deny-by-default
- **Security Hardening** — All critical issues resolved (hardcoded secrets removed, account-agnostic configs)

### 📊 Monitoring & Observability
- **Real-Time User Analytics** — CloudWatch RUM + custom analytics with visitor tracking and engagement metrics
- **Prometheus + Grafana** — Advanced metrics visualization with 15+ pre-built dashboards
- **CloudWatch Integration** — Application logs, metrics, alarms, and Insights queries
- **ALB Access Logs** — Detailed traffic analysis with Lambda-based custom metrics
- **Health Checks** — Automated monitoring scripts with alerting

### 🏗️ Infrastructure
- **Production VPC** — Multi-AZ deployment with public/private subnets and NAT gateways
- **Application Load Balancer** — SSL/TLS termination with Auto Scaling Group
- **ECS Fargate** — Containerized Ghost blog with blue-green deployments
- **Optional Add-ons** — RDS MySQL, ElastiCache Redis, CloudFront CDN (modules ready, not deployed by default)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Actions                          │
│  Terraform CI/CD │ Ansible CI/CD │ Blue-Green │ Security Scan  │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                           AWS Account                            │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                        VPC (Multi-AZ)                     │  │
│  │                                                            │  │
│  │  ┌──────────────┐         ┌──────────────┐              │  │
│  │  │ Public Subnet│         │ Public Subnet│              │  │
│  │  │   (AZ-1)     │         │   (AZ-2)     │              │  │
│  │  │              │         │              │              │  │
│  │  │   ALB (Blue) │         │   ALB (Green)│              │  │
│  │  │   Target     │         │   Target     │              │  │
│  │  └──────┬───────┘         └──────┬───────┘              │  │
│  │         │                        │                       │  │
│  │  ┌──────▼────────┐        ┌──────▼────────┐            │  │
│  │  │ Private Subnet│        │ Private Subnet│            │  │
│  │  │   (AZ-1)      │        │   (AZ-2)      │            │  │
│  │  │               │        │               │            │  │
│  │  │ ECS Fargate   │        │ ECS Fargate   │            │  │
│  │  │ (Ghost Blog)  │        │ (Ghost Blog)  │            │  │
│  │  │ Auto Scaling  │        │ Auto Scaling  │            │  │
│  │  │               │        │               │            │  │
│  │  └───────────────┘        └───────────────┘            │  │
│  │                                                          │  │
│  │  Monitoring:                Analytics:                  │  │
│  │  • Prometheus (ECS)        • CloudWatch RUM            │  │
│  │  • Grafana (ECS)           • Custom Metrics Lambda     │  │
│  │  • CloudWatch Logs         • ALB Access Logs           │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Data Flow**:
1. User accesses `https://blog.yourdomain.com`
2. ALB routes to active target group (Blue or Green)
3. ECS Fargate serves Ghost blog
4. CloudWatch RUM tracks user interactions
5. Lambda processes ALB logs for custom analytics
6. Prometheus scrapes ECS metrics
7. Grafana visualizes all data sources

---

## Quick Start

### Prerequisites

- **AWS Account** with admin access
- **GitHub Account** with repository
- **Terraform** >= 1.7.0
- **Ansible** >= 2.14
- **AWS CLI** configured locally
- **Domain name** with ACM certificate

### 1. Clone & Setup

```bash
# Clone repository
git clone https://github.com/YOUR-ORG/Secure_AWS_Infrastructure.git
cd Secure_AWS_Infrastructure

# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Install all required tools (optional)
./scripts/setup/install-tools.sh
```

### 2. Create Backend Infrastructure

```bash
# Bootstrap Terraform backend (S3 + DynamoDB)
./scripts/bootstrap.sh
```

This creates:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- KMS key for state encryption

### 3. Configure

```bash
cd terraform

# Copy backend config template
cp backend-config.hcl.example backend-config.hcl
# Edit with your S3 bucket and DynamoDB table names

# Copy variables template
cp terraform.tfvars.example terraform.tfvars
# Edit with your configuration (see Configuration section below)

# Set sensitive variables via environment
export TF_VAR_grafana_admin_password='SecurePassword123!'
export TF_VAR_acm_certificate_arn='arn:aws:acm:REGION:ACCOUNT:certificate/ID'
export TF_VAR_grafana_certificate_arn='arn:aws:acm:REGION:ACCOUNT:certificate/ID'
```

### 4. Deploy

```bash
# Initialize Terraform
terraform init -backend-config=backend-config.hcl

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply

# View outputs
terraform output
```

**That's it!** Infrastructure is deployed. Access your Ghost blog at the ALB DNS name (output: `alb_dns_name`).

---

## Configuration

### GitHub Secrets (Required)

**Recommended: Use OIDC** (keyless authentication):

1. Deploy OIDC provider:
   ```bash
   terraform apply -target=module.oidc_role
   terraform output github_oidc_role_arn
   ```

2. Add to GitHub Secrets (**Settings → Secrets → Actions**):
   - `AWS_ROLE_ARN` — From Terraform output above

**Alternative: Long-lived credentials** (not recommended):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**Terraform Variables** (passed as secrets):
- `TF_VAR_grafana_admin_password`
- `TF_VAR_acm_certificate_arn`
- `TF_VAR_grafana_certificate_arn`

### Terraform Variables (terraform.tfvars)

**Required**:
```hcl
aws_region              = "us-east-1"
environment             = "production"
vpc_cidr                = "10.0.0.0/16"
enable_nat_gateway      = true

# Domains (must have ACM certificates)
ghost_domain_name       = "blog.yourdomain.com"
grafana_domain_name     = "grafana.yourdomain.com"
```

**Optional Features**:
```hcl
# Observability (Prometheus + Grafana)
enable_observability      = true
prometheus_retention_days = 15

# User Analytics (CloudWatch RUM + custom metrics)
enable_user_analytics = true

# Ghost Blog on ECS
enable_ghost_blog = true
ghost_image       = "ghost:5"

# Blue-Green Deployment
enable_blue_green = false  # Enable for zero-downtime updates
```

**Cost Optimization**:
```hcl
enable_nat_gateway = false  # Use public subnets only (saves ~$32/month)
instance_type      = "t3.micro"  # Or t3.small for production
```

### Multi-Environment Deployments

Use Terraform workspaces:

```bash
# Create environments
terraform workspace new dev
terraform workspace new staging
terraform workspace new production

# Switch and deploy
terraform workspace select production
terraform apply -var-file=production.tfvars
```

---

## Infrastructure Components

### Terraform Modules

| Module | Purpose | Status |
|--------|---------|--------|
| **vpc** | Multi-AZ VPC with public/private subnets | ✅ Active |
| **alb_asg** | Application Load Balancer + Auto Scaling | ✅ Active |
| **ecs_ghost** | Ghost blog on ECS Fargate | ✅ Active |
| **ecs_bluegreen** | Blue-green deployment for ECS | ⚙️ Optional |
| **monitoring** | CloudWatch dashboards + alarms | ✅ Active |
| **observability** | Prometheus + Grafana on ECS | ⚙️ Optional |
| **user_analytics** | CloudWatch RUM + custom analytics | ⚙️ Optional |
| **oidc_role** | GitHub OIDC authentication | ✅ Active |
| **rds_mysql** | RDS MySQL database | 📦 Available |
| **elasticache_redis** | ElastiCache Redis cluster | 📦 Available |
| **cloudfront** | CloudFront CDN distribution | 📦 Available |

**📦 Available modules** exist but are not deployed by default. Enable in `main.tf`.

### Ansible Playbooks

**Webserver Playbook** (`ansible/playbooks/webserver.yml`):
- Installs and configures nginx
- Deploys responsive web application
- Configures SSL/TLS with Let's Encrypt
- Sets up security headers (CSP, HSTS, X-Frame-Options)
- Enables dark mode and WCAG accessibility
- Performance optimization (Gzip, caching, HTTP/2)

**Usage**:
```bash
cd ansible

# Deploy to all EC2 instances
ansible-playbook playbooks/webserver.yml

# Deploy to specific environment
ansible-playbook playbooks/webserver.yml -e environment=production

# Check mode (dry run)
ansible-playbook playbooks/webserver.yml --check
```

---

## CI/CD Pipeline

### GitHub Actions Workflows

#### 1. **Terraform CI/CD** (`.github/workflows/terraform-ci-cd.yml`)
**Triggers**: Push to `main`, PR, manual

**Jobs**:
- Validate → Format check → Plan → Security scan → Apply → Notify

**Features**:
- Automatic plan on PR with comment
- Manual approval for production
- Drift detection
- Cost estimation with Infracost

#### 2. **Ansible CI/CD** (`.github/workflows/ansible-ci-cd.yml`)
**Triggers**: Changes to `ansible/`, manual

**Jobs**:
- Syntax check → Linting → Dry run → Deploy → Verify

**Features**:
- ansible-lint validation
- Check mode before apply
- Idempotency verification

#### 3. **Blue-Green Deployment** (`.github/workflows/blue-green-deployment.yml`)
**Triggers**: Manual only

**Jobs**:
- Build new image → Deploy to green → Health check → Switch traffic → Monitor

**Features**:
- Zero-downtime updates
- Automatic rollback on failure
- Traffic shifting (10% → 50% → 100%)

#### 4. **Security Scan** (`.github/workflows/security-scan.yml`)
**Triggers**: Daily cron, PR, manual

**Tools**:
- Checkov (IaC policy-as-code)
- tfsec (Terraform security)
- Trivy (container vulnerabilities)
- TruffleHog (secret scanning)
- Gitleaks (credential detection)
- ansible-lint (playbook best practices)

#### 5. **PR Validation** (`.github/workflows/pr-validation.yml`)
**Triggers**: All pull requests

**Checks**:
- Terraform validate + fmt
- Ansible syntax
- Markdown linting
- JSON/YAML validation
- Link checking

#### 6. **Dependency Updates** (`.github/workflows/dependency-update.yml`)
**Triggers**: Weekly cron

**Actions**:
- Terraform provider updates
- GitHub Actions updates
- Pre-commit hook updates
- Automated PR creation

### Pre-Commit Hooks

**20+ automated checks** before every commit:

```yaml
# Security
- TruffleHog (secrets)
- Gitleaks (credentials)
- detect-secrets (baseline)

# Terraform
- terraform fmt
- terraform validate
- terraform-docs (auto-generate docs)
- tfsec
- checkov

# Ansible
- ansible-lint
- ansible-syntax-check

# Code Quality
- shellcheck (shell scripts)
- yamllint
- markdownlint
- prettier (JSON/YAML/MD)

# Python
- black (formatting)
- flake8 (linting)
- isort (import sorting)
```

**Setup**:
```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files  # Test all hooks
```

---

## Security

### ✅ Critical Security Fixes Applied

All hardcoded secrets and account-specific values have been removed:

1. **Secrets removed** — Grafana password no longer in terraform.tfvars
2. **ARNs parameterized** — ACM certificate ARNs via environment variables
3. **Backend externalized** — S3/DynamoDB config in separate file
4. **Domains parameterized** — No hardcoded domain names
5. **Production safeguards** — VPC prevent_destroy documentation

### Security Best Practices

**Secrets Management**:
- ✅ Use AWS Secrets Manager for application secrets
- ✅ Use GitHub Secrets for CI/CD credentials
- ✅ Never commit secrets to git
- ✅ Rotate credentials every 90 days

**Access Control**:
- ✅ Use OIDC over long-lived credentials
- ✅ Enable MFA on all IAM users
- ✅ Least-privilege IAM policies
- ✅ Separate roles per environment

**Infrastructure Protection**:
- ✅ Set `prevent_destroy = true` for production VPC
- ✅ Enable S3 versioning for state files
- ✅ Enable DynamoDB point-in-time recovery
- ✅ Review security group rules regularly

**Monitoring & Compliance**:
- ✅ Enable CloudTrail for audit logging
- ✅ Enable GuardDuty for threat detection (optional)
- ✅ Configure CloudWatch alarms
- ✅ Enable VPC Flow Logs

### Security Incident Response

If secrets were exposed:

1. **Rotate immediately**:
   ```bash
   export TF_VAR_grafana_admin_password='NewPassword!'
   terraform apply
   ```

2. **Review git history**:
   ```bash
   git log -p | grep -i "password\|secret"

   # Use trufflehog for comprehensive scan
   docker run --rm -v $(pwd):/repo \
     trufflesecurity/trufflehog:latest git file:///repo
   ```

3. **Remove from history** (if necessary):
   ```bash
   # WARNING: Rewrites git history
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch terraform/terraform.tfvars" \
     --prune-empty -- --all
   ```

---

## Monitoring & Analytics

### CloudWatch RUM (Real User Monitoring)

**Features**:
- Page load times
- JavaScript errors
- User sessions and paths
- Device/browser analytics
- Geographic data

**Setup**:
1. Enable in `terraform.tfvars`:
   ```hcl
   enable_user_analytics = true
   ```

2. Add RUM script to Ghost theme (`content/themes/YOUR-THEME/default.hbs`):
   ```html
   <script>
   (function(n,i,v,r,s,c,x,z){/* CloudWatch RUM snippet */})();
   </script>
   ```

3. View data:
   ```bash
   # CloudWatch Console → RUM → Application Monitoring
   # Or via AWS CLI
   aws rum get-app-monitor --name ghost-blog-rum
   ```

### Custom Analytics

**Lambda-based pageview and engagement tracking**:

| Metric | Description |
|--------|-------------|
| `pageviews` | Total page views with URL breakdown |
| `unique_visitors` | Distinct IP addresses |
| `engagement_time` | Time spent on pages |
| `bounce_rate` | Single-page sessions |
| `device_type` | Desktop/mobile/tablet split |

**CloudWatch Insights Queries**:
```sql
# Top 10 most viewed pages
fields @timestamp, page_url, view_count
| filter metric_name = "pageviews"
| stats sum(view_count) as total_views by page_url
| sort total_views desc
| limit 10

# User engagement by device type
fields @timestamp, device_type, engagement_seconds
| filter metric_name = "engagement"
| stats avg(engagement_seconds) as avg_time by device_type
```

### Prometheus + Grafana

**Deployed on ECS Fargate** (optional: `enable_observability = true`)

**Access**:
- Grafana: `https://grafana.yourdomain.com`
- Prometheus: Internal only (scraped by Grafana)

**Pre-built Dashboards**:
- AWS ECS Fargate Overview
- Prometheus 2.0 Stats
- Node Exporter Full
- Container Insights
- ALB Performance

**Metrics Collected**:
- ECS task CPU/memory/network
- Container performance
- ALB request count/latency/errors
- Custom application metrics

**Retention**: 15 days (configurable via `prometheus_retention_days`)

### ALB Access Logs

**Stored in S3** with Lambda processing for custom metrics:

```bash
# View logs
aws s3 ls s3://YOUR-BUCKET/alb-logs/

# Query with Athena
aws athena start-query-execution --query-string \
  "SELECT request_url, COUNT(*) as hits FROM alb_logs GROUP BY request_url ORDER BY hits DESC LIMIT 10"
```

---

## Blue-Green Deployments

**Zero-downtime deployment strategy** for ECS Ghost blog updates.

### Architecture

```
ALB
 ├─ Blue Target Group (Active)
 │   └─ ECS Service (Current version)
 └─ Green Target Group (Standby)
     └─ ECS Service (New version)
```

### Deployment Flow

1. **Deploy Green** — New version to standby target group
2. **Health Check** — Verify green is healthy
3. **Shift Traffic** — Gradual: 10% → 50% → 100%
4. **Monitor** — CloudWatch alarms for error rates
5. **Complete** — Green becomes active, blue becomes standby

### Usage

**Via GitHub Actions**:
```
Actions → Blue-Green Deployment → Run workflow
→ Enter new image tag → Run
```

**Via Terraform**:
```hcl
# In terraform.tfvars
enable_blue_green = true
ghost_image       = "ghost:5.0.0"  # New version

# Apply
terraform apply
```

**Via Scripts**:
```bash
# Deploy new version
./scripts/blue-green/deploy.sh ghost:5.0.0

# Check status
./scripts/blue-green/status.sh

# Rollback if needed
./scripts/blue-green/rollback.sh
```

### Rollback

**Instant rollback** if issues detected:

```bash
# Automatic rollback on alarm
# CloudWatch alarm triggers Lambda → switches traffic back

# Manual rollback
./scripts/blue-green/rollback.sh

# Via GitHub Actions
Actions → Blue-Green Deployment → Run workflow → Select "Rollback"
```

---

## Cost Estimation

### Base Infrastructure (~$50-65/month)

| Component | Monthly Cost |
|-----------|--------------|
| **VPC** | Free |
| **NAT Gateway** (2 AZs) | ~$32 |
| **Application Load Balancer** | ~$16 |
| **ECS Fargate** (1 task, 0.5 vCPU, 1GB) | ~$15 |
| **S3** (state + logs, 5GB) | ~$0.12 |
| **DynamoDB** (state locking) | Free tier |
| **CloudWatch Logs** (10GB) | ~$5 |
| **Total Base** | **~$68/month** |

### Optional Add-ons

| Component | Monthly Cost |
|-----------|--------------|
| **Prometheus + Grafana** (1 task, 1 vCPU, 2GB) | ~$30 |
| **CloudWatch RUM** (10K sessions) | ~$10 |
| **Custom Analytics Lambda** | ~$1 |
| **RDS MySQL** (db.t3.micro) | ~$15 |
| **ElastiCache Redis** (cache.t3.micro) | ~$12 |
| **CloudFront** (100GB transfer) | ~$10 |

### Cost Optimization

**Save ~50% ($32/month)**:
```hcl
# Use public subnets only (no NAT gateway)
enable_nat_gateway = false

# Use smaller instances
instance_type = "t3.micro"
```

**Free Tier Eligible** (first 12 months):
- EC2: 750 hours/month
- S3: 5GB storage
- ALB: 750 hours/month
- RDS: 750 hours db.t2.micro

**Cost Monitoring**:
```bash
# View current costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost

# Set up budget alert
aws budgets create-budget \
  --account-id YOUR-ACCOUNT-ID \
  --budget file://budget.json
```

---

## Troubleshooting

### Terraform Issues

**Error: Backend configuration changed**
```bash
# Re-initialize with new backend config
terraform init -reconfigure -backend-config=backend-config.hcl
```

**Error: Resource already exists**
```bash
# Import existing resource
terraform import aws_kms_alias.beta alias/your-alias

# Or delete and recreate
aws kms delete-alias --alias-name alias/your-alias
terraform apply
```

**Error: State locked**
```bash
# Force unlock (use carefully)
terraform force-unlock LOCK_ID
```

### Ansible Issues

**Error: Permission denied (publickey)**
```bash
# Verify SSH key in AWS EC2 console
# Add key to ssh-agent
ssh-add ~/.ssh/your-key.pem
```

**Error: Module not found**
```bash
# Install Ansible collections
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
```

**Idempotency check failed**
```bash
# Run in check mode first
ansible-playbook playbooks/webserver.yml --check

# Compare runs
ansible-playbook playbooks/webserver.yml --diff
```

### GitHub Actions Issues

**Error: OIDC role not found**
```bash
# Deploy OIDC provider
terraform apply -target=module.oidc_role

# Add AWS_ROLE_ARN to GitHub Secrets
```

**Error: Terraform plan failed**
```bash
# Check logs in Actions tab
# Verify all required secrets are set
# Ensure backend configuration is correct
```

### Ghost Blog Issues

**Container health check failing**
```bash
# Check ECS task logs
aws ecs describe-tasks --cluster ghost-cluster --tasks TASK-ID

# View CloudWatch logs
aws logs tail /ecs/ghost --follow

# Common fix: Update health check to accept 301 redirects
```

**DNS not resolving**
```bash
# Verify Route53 record
aws route53 list-resource-record-sets --hosted-zone-id YOUR-ZONE-ID

# Check ALB DNS
terraform output alb_dns_name

# Update DNS to point to correct ALB
```

### Monitoring Issues

**Grafana: Connection refused**
```bash
# Check ECS service is running
aws ecs describe-services --cluster monitoring --services grafana

# Verify security group allows port 3000
aws ec2 describe-security-groups --group-ids sg-XXXXX

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn arn:aws:...
```

**Prometheus: No metrics**
```bash
# Verify Prometheus config
aws ecs describe-task-definition --task-definition prometheus

# Check service discovery
curl http://prometheus:9090/api/v1/targets

# Restart Prometheus service
aws ecs update-service --cluster monitoring --service prometheus --force-new-deployment
```

### Cost Troubleshooting

**Unexpected high costs**
```bash
# Identify top cost drivers
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=SERVICE

# Check for orphaned resources
./scripts/monitoring/health-check.sh

# Review NAT gateway data transfer
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToSource \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 86400 \
  --statistics Sum
```

---

## Makefile Commands

**37 unified automation commands**:

### Development
```bash
make help              # Show all available commands
make validate          # Validate all code (Terraform + Ansible + Shell)
make format            # Format all code
make test              # Run all tests
make pre-commit        # Run pre-commit hooks
```

### Terraform
```bash
make tf-init           # Initialize Terraform
make tf-plan           # Plan infrastructure changes
make tf-apply          # Apply infrastructure
make tf-destroy        # Destroy all infrastructure (CAUTION)
make tf-output         # Show Terraform outputs
make tf-refresh        # Refresh state
make tf-validate       # Validate Terraform code
make tf-fmt            # Format Terraform files
```

### Ansible
```bash
make ansible-lint      # Lint Ansible playbooks
make ansible-syntax    # Check syntax
make ansible-check     # Dry run (check mode)
make ansible-deploy    # Deploy with Ansible
make ansible-verify    # Verify idempotency
```

### Security
```bash
make security-scan     # Run all security scans
make tfsec             # Terraform security scan
make checkov           # Policy-as-code scan
make trivy             # Container vulnerability scan
make secrets-scan      # Secret detection scan
```

### Deployment
```bash
make deploy-all        # Full deployment (Terraform + Ansible)
make deploy-ghost      # Deploy Ghost blog only
make deploy-monitoring # Deploy Prometheus + Grafana
make blue-green-deploy # Blue-green deployment
make rollback          # Rollback to previous version
```

### Monitoring
```bash
make health-check      # Check infrastructure health
make get-metrics       # Fetch CloudWatch metrics
make logs              # Tail CloudWatch logs
make dashboard         # Open Grafana dashboard
```

### Cleanup
```bash
make clean             # Clean temporary files
make clean-all         # Clean all generated files
make cleanup-buckets   # Empty S3 buckets
make cleanup-logs      # Delete old CloudWatch logs
```

---

## Idempotency

This infrastructure is **fully idempotent** — safe to run repeatedly without side effects.

### Terraform Idempotency

- ✅ **State Locking** — DynamoDB prevents concurrent modifications
- ✅ **Resource Tracking** — State file tracks all resources
- ✅ **Lifecycle Rules** — `prevent_destroy`, `ignore_changes`, `create_before_destroy`
- ✅ **Version Pinning** — Locked provider versions in `.terraform.lock.hcl`

### Ansible Idempotency

- ✅ **Idempotent Modules** — apt, copy, template, service, etc.
- ✅ **Check Mode** — Dry run before apply (`--check`)
- ✅ **Changed Detection** — Only reports actual changes (`changed_when`)
- ✅ **Handlers** — Run once at end, only if notified

### Verification

```bash
# Run twice, should show no changes on second run
make tf-plan   # Should show: No changes
make tf-apply  # Should show: Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

make ansible-deploy  # Should show: ok=X changed=0
make ansible-deploy  # Should show: ok=X changed=0 (same results)
```

---

## Contributing

### Development Workflow

1. **Create branch**:
   ```bash
   git checkout -b feature/your-feature
   ```

2. **Make changes**:
   - Update Terraform modules in `terraform/modules/`
   - Update Ansible playbooks in `ansible/playbooks/`
   - Update documentation

3. **Test locally**:
   ```bash
   make validate
   make test
   pre-commit run --all-files
   ```

4. **Commit**:
   ```bash
   git add .
   git commit -m "feat: your feature description"
   # Pre-commit hooks run automatically
   ```

5. **Push and create PR**:
   ```bash
   git push origin feature/your-feature
   # Open pull request on GitHub
   # CI/CD runs automatically
   ```

### Commit Message Format

Use conventional commits:

- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation only
- `style:` — Formatting, no code change
- `refactor:` — Code refactoring
- `perf:` — Performance improvement
- `test:` — Adding tests
- `chore:` — Maintenance

### Code Standards

- **Terraform**: Follow [HashiCorp style guide](https://www.terraform.io/docs/language/syntax/style.html)
- **Ansible**: Follow [Ansible best practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- **Shell**: Use ShellCheck recommendations
- **Python**: PEP 8 with Black formatter

---

## License

GPL-3.0 License — See [LICENSE](LICENSE) file

---

## Support & Resources

### External Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

### Getting Help

- **Issues**: Open a GitHub issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Report security issues privately to maintainers

---

**Status**: ✅ Production Ready
**Last Updated**: 2026-02-19
**Maintained By**: Infrastructure Team

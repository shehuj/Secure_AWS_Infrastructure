# Secure AWS Infrastructure

Production-ready AWS infrastructure using Terraform, Ansible, and GitHub Actions. Deploys a secure, multi-AZ environment with a Ghost blog on ECS Fargate, an ALB-backed Auto Scaling Group, optional Prometheus/Grafana observability, and keyless GitHub OIDC authentication.

---

## Architecture Overview

```
                          ┌─────────────────────────────┐
                          │         Route 53 DNS         │
                          └──────────────┬──────────────┘
                                         │
                    ┌────────────────────▼────────────────────┐
                    │      Application Load Balancer (ALB)     │
                    │   HTTPS (443) ──► Target Group          │
                    │   HTTP  (80)  ──► Redirect to HTTPS     │
                    └──────┬───────────────────┬─────────────┘
                           │                   │
               ┌───────────▼───┐       ┌───────▼───────────┐
               │  ASG (EC2)    │       │  ECS Fargate       │
               │  t3.micro x2  │       │  Ghost Blog        │
               │  nginx + app  │       │  (2 tasks)         │
               └───────────────┘       └───────────────────┘
                           │                   │
               ┌───────────▼───────────────────▼───────────┐
               │                  VPC                        │
               │   Public Subnets:  10.0.1.0/24             │
               │                   10.0.2.0/24              │
               │   Private Subnets: 10.0.3.0/24             │
               │                   10.0.4.0/24              │
               └────────────────────────────────────────────┘
```

**Region:** us-east-1 | **Multi-AZ:** 2 AZs | **State:** S3 + DynamoDB locking

---

## Terraform Modules

| Module | Status | Description |
|---|---|---|
| `vpc` | Always on | Multi-AZ VPC, public/private subnets, NAT Gateway, VPC Flow Logs |
| `alb_asg` | Always on | ALB with SSL/TLS, Auto Scaling Group (2–3 × t3.micro), SSM access |
| `ecs_ghost` | Always on | Ghost blog on ECS Fargate, Route 53 DNS, ACM certificate |
| `monitoring` | Always on | CloudWatch dashboards, alarms, SNS notifications |
| `oidc_role` | Always on | GitHub OIDC provider for keyless CI/CD authentication |
| `observability` | Optional | Prometheus + Grafana on ECS Fargate (`enable_observability = true`) |
| `user_analytics` | Optional | CloudWatch RUM + Lambda analytics (`enable_user_analytics = true`) |
| `ecs_bluegreen` | Optional | Zero-downtime blue-green deployments via CodeDeploy |
| `rds_mysql` | Available | Managed MySQL RDS (not deployed by default) |
| `elasticache_redis` | Available | ElastiCache Redis cluster (not deployed by default) |

---

## CI/CD Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `terraform-plan.yml` | PR → `main`/`dev` | Validates, lints, plans, posts output as PR comment |
| `terraform-apply.yml` | Push → `main`/`dev`, manual dispatch | Applies Terraform changes; prod requires manual dispatch |
| `terraform-cleanup.yml` | Manual dispatch | Safeguarded destroy with pre-cleanup, plan preview, and post-verify |
| `security-scan.yml` | Daily 2 AM UTC, push, PR, manual | TruffleHog, Gitleaks, Checkov, tfsec, OWASP, CodeQL, container scanning |
| `pr-validation.yml` | All PRs | Commit format, PR size, auto-labeling, docs check |
| `ansible-deploy.yml` | Manual dispatch | Deploys Ansible configuration post-Terraform |
| `ansible-ci-cd.yml` | `ansible/` changes, manual | Syntax check, ansible-lint, molecule tests |
| `ghost-deploy.yml` | Manual dispatch | Ghost ECS deployment with health checks and auto-rollback |
| `blue-green-deployment.yml` | Push → `main` (`app/*`), manual | Zero-downtime ECS blue-green with gradual traffic shifting |
| `dependency-update.yml` | Weekly Monday 9 AM UTC | Updates Terraform providers, Ansible collections, GitHub Actions |

---

## Prerequisites

- AWS account with admin access
- Terraform >= 1.7.0
- Ansible >= 2.14
- AWS CLI v2
- ACM certificate for your domain (must be in `us-east-1`)
- Route 53 hosted zone

---

## Quick Start

### 1. Bootstrap the backend

```bash
./scripts/setup/install-tools.sh   # installs Terraform, Ansible, AWS CLI
./scripts/bootstrap.sh             # creates S3 bucket + DynamoDB table for Terraform state
```

### 2. Configure the backend

```bash
cp terraform/backend-config.hcl.example terraform/backend-config.hcl
# Edit backend-config.hcl with your S3 bucket and DynamoDB table names
```

### 3. Set GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `AWS_REGION` | Target region (e.g. `us-east-1`) |
| `TF_VAR_ROUTE53_ZONE_ID` | Route 53 hosted zone ID |
| `TF_VAR_ACM_CERTIFICATE_ARN` | ACM certificate ARN for the main ALB |
| `TF_VAR_GRAFANA_CERTIFICATE_ARN` | ACM certificate ARN for Grafana |
| `TF_VAR_GRAFANA_DOMAIN_NAME` | Grafana domain (e.g. `grafana.example.com`) |
| `TF_VAR_GRAFANA_ADMIN_PASSWORD` | Grafana admin password |
| `TF_VAR_ROOT_VOLUME_SIZE` | EC2 root volume size in GB (minimum `30`) |
| `TF_VAR_ENABLE_OBSERVABILITY` | `true` to deploy Prometheus + Grafana |
| `TF_VAR_PROMETHEUS_RETENTION_DAYS` | Prometheus data retention days |

### 4. Deploy infrastructure

```bash
# Via CI/CD (recommended) — push to main triggers terraform-apply.yml
git push origin main

# Or deploy locally
cd terraform
terraform init -backend-config=../backend-config.hcl
terraform plan
terraform apply
```

### 5. Configure EC2 instances

```bash
# Trigger ansible-deploy.yml via GitHub Actions, or run locally:
cd ansible
ansible-playbook -i inventory/aws_ec2.yml playbooks/webserver.yml
```

---

## Configuration Reference

All variables are injected into CI via GitHub Secrets (`TF_VAR_*`). The `terraform.tfvars` file committed to this repo is intentionally empty. For local development, use your own tfvars file:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars.local
terraform plan -var-file=terraform.tfvars.local
```

### Core Variables

| Variable | Default | Description |
|---|---|---|
| `environment` | `prod` | Environment name (`dev`, `staging`, `prod`) |
| `aws_region` | `us-east-1` | AWS region |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `instance_type` | `t3.micro` | EC2 instance type for ASG |
| `root_volume_size` | `20` | EC2 root volume GB (set to `30`+ via secret) |
| `ghost_domain_name` | — | Domain for Ghost blog (required) |
| `ghost_image` | `ghost:latest` | Ghost Docker image |
| `acm_certificate_arn` | — | ACM cert ARN for ALB HTTPS (required) |
| `route53_zone_id` | — | Route 53 zone ID |

### Monitoring Variables

| Variable | Default | Description |
|---|---|---|
| `log_retention_days` | `30` | CloudWatch log retention days |
| `cpu_threshold` | `80` | CPU alarm threshold (%) |
| `memory_threshold` | `80` | Memory alarm threshold (%) |
| `create_sns_topic` | `false` | Create SNS topic for alarm emails |
| `alarm_email_endpoints` | `[]` | Email addresses for alarm notifications |
| `create_dashboard` | `true` | Create CloudWatch dashboard |

### Optional Features

| Variable | Default | Description |
|---|---|---|
| `enable_observability` | `false` | Deploy Prometheus + Grafana stack |
| `grafana_domain_name` | — | Grafana domain |
| `grafana_certificate_arn` | — | ACM cert for Grafana |
| `grafana_admin_password` | — | Grafana admin password (sensitive) |
| `prometheus_retention_days` | `15` | Prometheus retention days |
| `enable_user_analytics` | `false` | Deploy CloudWatch RUM + analytics |
| `rum_sample_rate` | `1.0` | RUM session sampling rate (0.0–1.0) |
| `alb_log_retention_days` | `90` | ALB access log retention in S3 |

---

## Repository Structure

```
.
├── .github/
│   ├── labeler.yml
│   └── workflows/
│       ├── ansible-ci-cd.yml
│       ├── ansible-deploy.yml
│       ├── blue-green-deployment.yml
│       ├── dependency-update.yml
│       ├── ghost-deploy.yml
│       ├── pr-validation.yml
│       ├── security-scan.yml
│       ├── terraform-apply.yml
│       ├── terraform-cleanup.yml
│       └── terraform-plan.yml
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/aws_ec2.yml        # Dynamic EC2 inventory
│   ├── playbooks/webserver.yml      # nginx + SSL + security headers
│   ├── templates/                   # Jinja2 HTML templates
│   └── files/                       # Static CSS/JS assets
├── scripts/
│   ├── bootstrap.sh                 # Creates S3/DynamoDB backend
│   ├── test-idempotency.sh
│   ├── blue-green/                  # deploy.sh, rollback.sh, status.sh
│   ├── deploy/full-deployment.sh    # End-to-end Terraform + Ansible
│   ├── monitoring/                  # health-check.sh, get-metrics.sh
│   └── setup/install-tools.sh
├── terraform/
│   ├── backend.tf
│   ├── provider.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars             # Empty — values injected via CI secrets
│   ├── terraform.tfvars.example     # Reference template for local dev
│   ├── backend-config.hcl.example
│   └── modules/
│       ├── alb_asg/
│       ├── ecs_bluegreen/
│       ├── ecs_ghost/
│       ├── elasticache_redis/
│       ├── monitoring/
│       ├── observability/
│       ├── oidc_role/
│       ├── rds_mysql/
│       ├── user_analytics/
│       └── vpc/
├── Makefile                         # 37 automation commands (run `make help`)
├── .pre-commit-config.yaml          # 20+ pre-commit checks
├── .tflint.hcl
├── .yamllint
└── sonar-project.properties
```

---

## Security

### Authentication
- **GitHub Actions → AWS**: OIDC keyless authentication — no long-lived keys in CI
- **EC2 → AWS APIs**: IAM instance profile with least-privilege policy
- **EC2 access**: AWS Systems Manager Session Manager — no SSH, no open port 22

### Network
- Port 80 redirects immediately to HTTPS (301)
- ALB drops invalid HTTP headers (`drop_invalid_header_fields = true`)
- EC2 instances only accept traffic from the ALB security group
- Default VPC security group has all rules removed
- VPC Flow Logs enabled

### Data
- EBS volumes encrypted at rest
- S3 buckets: public access blocked, AES-256 server-side encryption
- Terraform state encrypted in S3

### Scanning (security-scan.yml — runs daily + on every push/PR)

| Tool | What it checks |
|---|---|
| TruffleHog | Secrets in git history |
| Gitleaks | Credentials and API keys |
| Checkov | Terraform policy-as-code (soft fail — warns only) |
| tfsec | Terraform security misconfigurations |
| OWASP Dependency Check | Known CVEs in dependencies |
| CodeQL | Static application security testing |
| Trivy | Container image vulnerabilities |
| ansible-lint | Ansible security profile |

---

## Destroy / Cleanup

Use the **Terraform Cleanup & Destroy** workflow — manual dispatch only:

1. **Actions → Terraform Cleanup & Destroy → Run workflow**
2. Select environment
3. Type `DESTROY` in the confirmation field

The workflow automatically:
1. Scales ECS services to 0
2. Deregisters Service Discovery instances
3. Disables ALB deletion protection
4. Empties S3 buckets
5. Drains ASG instances
6. Runs `terraform plan -destroy` (preview shown before applying)
7. Executes `terraform destroy`
8. Verifies and reports remaining resources

---

## Local Development

```bash
# Install all required tools
./scripts/setup/install-tools.sh

# Set up pre-commit hooks
pip install pre-commit && pre-commit install

# Plan against real backend with a local tfvars
cd terraform
terraform init -backend-config=../backend-config.hcl
terraform plan -var-file=terraform.tfvars.local

# Common Makefile commands
make help           # list all commands
make validate       # terraform validate + fmt check
make plan           # terraform plan
make apply          # terraform apply
make security       # run all security scans locally
make fmt            # format all Terraform files
make ansible-lint   # lint Ansible playbooks
make deploy         # full Terraform + Ansible deployment
make clean          # remove local .terraform directories
```

---

## Cost Estimate

| Component | Monthly |
|---|---|
| EC2 (2× t3.micro) + ALB | ~$35 |
| ECS Fargate — Ghost (2 tasks) | ~$15 |
| NAT Gateway | ~$10 |
| VPC Flow Logs + CloudWatch | ~$8 |
| **Base total** | **~$68** |
| + Prometheus/Grafana ECS | ~$30 |
| + RDS MySQL (db.t3.micro) | ~$15 |
| + ElastiCache Redis | ~$12 |

Set `enable_nat_gateway = false` for dev/test environments to reduce to ~$36/month.

---

## License

[GPL-3.0](LICENSE)

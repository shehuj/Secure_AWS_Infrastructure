# Secure AWS Infrastructure

Production-ready AWS infrastructure using Terraform, Ansible, and GitHub Actions. Deploys a secure, multi-AZ environment with a Ghost blog on ECS Fargate backed by RDS MySQL, an ALB-backed Auto Scaling Group, optional Prometheus/Grafana observability, and keyless GitHub OIDC authentication.

---

## Architecture

```
                         Route 53 DNS
                              │
              ┌───────────────┴───────────────┐
              │         ALB (HTTPS/HTTP→HTTPS) │
              └───────┬───────────────┬────────┘
                      │               │
           ┌──────────▼───┐   ┌───────▼──────────┐
           │  ASG (EC2)   │   │   ECS Fargate     │
           │  t3.micro ×2 │   │   Ghost Blog ×2   │
           │  nginx       │   │   (mysql client)  │
           └──────────────┘   └───────┬──────────┘
                                      │
                              ┌───────▼──────────┐
                              │  RDS MySQL        │
                              │  (private subnet) │
                              └──────────────────┘
                      │               │
              ┌───────┴───────────────┴────────┐
              │              VPC               │
              │  Public:  10.0.1.0/24          │
              │           10.0.2.0/24          │
              │  Private: 10.0.3.0/24          │
              │           10.0.4.0/24          │
              └────────────────────────────────┘
```

**Region:** us-east-1 | **Multi-AZ:** 2 AZs | **State:** S3 + DynamoDB locking

---

## CI/CD Pipeline

Two workflows handle everything. **Open a PR → CI runs. Merge to `main` → CD deploys.**

### CI (`ci.yml`) — triggered on every PR to `main`

```
PR opened/updated
  ├── terraform validate + fmt check
  ├── terraform plan (output posted as PR comment)
  ├── Checkov security scan (soft fail)
  ├── ansible-lint
  └── TruffleHog secret scan
```

### CD (`cd.yml`) — triggered on merge to `main`

```
push to main
  └── terraform apply
        ├── ghost DB setup (Ansible → SSM → EC2 → RDS)
        └── webserver deploy (Ansible → EC2 ASG instances)
              └── Ghost ECS force-restart + health check
                    └── deployment summary
```

DB setup and webserver deploy run in parallel after Terraform completes.

### Utility Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `terraform-cleanup.yml` | Manual dispatch | Safeguarded destroy — scales to 0, empties buckets, runs `terraform destroy` |
| `terraform-unlock.yml` | Manual dispatch | Force-unlock stuck Terraform state by Lock ID |
| `security-scan.yml` | Daily 2 AM UTC | Deep scan: Checkov, tfsec, CodeQL, Trivy, OWASP, Gitleaks |
| `dependency-update.yml` | Weekly Monday | Bumps Terraform providers, Ansible collections, GitHub Actions |

---

## Terraform Modules

| Module | Deployed | Description |
|---|---|---|
| `vpc` | Always | Multi-AZ VPC, public/private subnets, NAT Gateway, VPC Flow Logs |
| `alb_asg` | Always | ALB (HTTPS), Auto Scaling Group (2–3 × t3.micro), SSM access |
| `ecs_ghost` | Always | Ghost blog on ECS Fargate, ACM cert, Route 53 DNS, EFS content volume |
| `rds_mysql` | Always | Managed MySQL on private subnets — provisioned by Terraform, configured by Ansible |
| `monitoring` | Always | CloudWatch dashboards, alarms, SNS |
| `oidc_role` | Always | GitHub OIDC provider for keyless CI/CD |
| `observability` | Optional | Prometheus + Grafana on ECS Fargate (`enable_observability = true`) |
| `user_analytics` | Optional | CloudWatch RUM + Lambda analytics (`enable_user_analytics = true`) |
| `ecs_bluegreen` | Available | Zero-downtime blue-green deployments via CodeDeploy |
| `elasticache_redis` | Available | ElastiCache Redis cluster |

---

## Terraform / Ansible Responsibility Split

| Responsibility | Terraform | Ansible |
|---|---|---|
| RDS instance, SGs, subnet group | ✅ | — |
| Master password (Secrets Manager) | ✅ | — |
| App user password (Secrets Manager) | ✅ | — |
| SSM parameters (`/prod/ghost/db/*`) | ✅ | — |
| Create `ghost` database + `ghost_app` user | — | ✅ (`ghost_db.yml`) |
| EC2 nginx configuration | — | ✅ (`webserver.yml`) |
| Ghost ECS task definition + service | ✅ | — |

Ansible connects to RDS indirectly: the `ghost_db.yml` playbook sends a shell script to an EC2 ASG instance via SSM `send-command`. The instance fetches credentials from Secrets Manager locally and runs the MySQL setup — no direct connectivity from CI to the private RDS subnet required.

---

## Prerequisites

- AWS account with admin access
- Terraform >= 1.7.0
- Ansible >= 2.14 (for local runs)
- AWS CLI v2
- ACM certificate for your domain (must be in `us-east-1`)
- Route 53 hosted zone

---

## Quick Start

### 1. Bootstrap the state backend

```bash
./scripts/bootstrap.sh   # creates S3 bucket + DynamoDB table
```

### 2. Set GitHub Secrets

Go to **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `AWS_REGION` | Target region (e.g. `us-east-1`) |
| `TF_VAR_ROUTE53_ZONE_ID` | Route 53 hosted zone ID |
| `TF_VAR_ACM_CERTIFICATE_ARN` | ACM cert ARN for the main ALB |
| `TF_VAR_GRAFANA_CERTIFICATE_ARN` | ACM cert ARN for Grafana ALB |
| `TF_VAR_GRAFANA_DOMAIN_NAME` | Grafana domain (e.g. `grafana.example.com`) |
| `TF_VAR_GRAFANA_ADMIN_PASSWORD` | Grafana admin password |
| `TF_VAR_ROOT_VOLUME_SIZE` | EC2 root volume GB (minimum `30`) |
| `TF_VAR_ENABLE_OBSERVABILITY` | `true` to deploy Prometheus + Grafana |
| `TF_VAR_PROMETHEUS_RETENTION_DAYS` | Prometheus data retention days |

### 3. Deploy

Open a PR to `main` — CI validates and posts a plan. Merge → CD deploys everything:

1. Terraform provisions all infrastructure (VPC, ALB, ASG, ECS, RDS, etc.)
2. Ansible creates the Ghost database and restricted MySQL user
3. Ansible configures nginx on EC2 instances
4. Ghost ECS tasks restart and connect to MySQL

```bash
# Or deploy locally
cd terraform
terraform init
terraform plan
terraform apply

cd ../ansible
ansible-playbook playbooks/ghost_db.yml -e app_environment=prod
ansible-playbook playbooks/webserver.yml -i inventory/aws_ec2.yml
```

---

## Configuration Reference

`terraform.tfvars` contains non-sensitive defaults. All sensitive values are injected via GitHub Secrets as `TF_VAR_*` environment variables.

### Core

| Variable | Default | Description |
|---|---|---|
| `environment` | `prod` | Environment name |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `instance_type` | `t3.micro` | EC2 instance type for ASG |
| `root_volume_size` | `30` | EC2 root volume GB |
| `ghost_domain_name` | — | Domain for Ghost blog |
| `ghost_image` | `ghost:latest` | Ghost Docker image |
| `acm_certificate_arn` | — | ACM cert ARN (required) |
| `route53_zone_id` | — | Route 53 zone ID |

### RDS

| Variable | Default | Description |
|---|---|---|
| `db_instance_class` | `db.t3.micro` | RDS instance class |
| `db_multi_az` | `false` | Enable Multi-AZ (recommended for prod) |

### Observability (optional)

| Variable | Default | Description |
|---|---|---|
| `enable_observability` | `false` | Deploy Prometheus + Grafana |
| `grafana_domain_name` | — | Grafana domain |
| `grafana_admin_password` | — | Grafana password (sensitive) |
| `prometheus_retention_days` | `15` | Prometheus retention days |

---

## Repository Structure

```
.
├── .github/workflows/
│   ├── ci.yml                  # PR: validate, plan, lint, secret scan
│   ├── cd.yml                  # Merge: apply → DB setup → webserver → restart
│   ├── terraform-cleanup.yml   # Manual: safeguarded destroy
│   ├── terraform-unlock.yml    # Manual: force-unlock state
│   ├── security-scan.yml       # Daily: deep security scanning
│   └── dependency-update.yml   # Weekly: version bump PRs
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/aws_ec2.yml   # Dynamic EC2 inventory
│   └── playbooks/
│       ├── ghost_db.yml        # Creates ghost DB + app user via SSM
│       └── webserver.yml       # nginx + security headers
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars        # Non-sensitive defaults
│   └── modules/
│       ├── vpc/
│       ├── alb_asg/
│       ├── ecs_ghost/
│       ├── rds_mysql/
│       ├── monitoring/
│       ├── observability/
│       ├── oidc_role/
│       ├── user_analytics/
│       ├── ecs_bluegreen/
│       └── elasticache_redis/
└── scripts/
    ├── bootstrap.sh
    └── setup/install-tools.sh
```

---

## Security

| Area | Implementation |
|---|---|
| CI → AWS auth | OIDC keyless — no long-lived keys stored in GitHub |
| EC2 access | SSM Session Manager — no SSH, port 22 closed |
| RDS access | Private subnet only, SG allows VPC CIDR on 3306 |
| DB credentials | Auto-generated, stored in Secrets Manager, never in code |
| HTTP traffic | Port 80 → 301 redirect to HTTPS |
| ALB headers | `drop_invalid_header_fields = true` |
| EC2 → ALB | Instances only accept traffic from ALB security group |
| Default SG | All rules removed from default VPC security group |
| EBS volumes | Encrypted at rest |
| Terraform state | Encrypted in S3, locked via DynamoDB |

---

## Destroy

Use **Actions → Terraform Cleanup & Destroy → Run workflow**, type `DESTROY` to confirm.

The workflow automatically scales ECS to 0, deregisters Service Discovery instances, empties S3 buckets, then runs `terraform destroy`.

---

## Cost Estimate

| Component | Monthly |
|---|---|
| EC2 (2× t3.micro) + ALB | ~$35 |
| ECS Fargate — Ghost (2 tasks) | ~$15 |
| RDS MySQL (db.t3.micro) | ~$15 |
| NAT Gateway | ~$10 |
| CloudWatch + VPC Flow Logs | ~$8 |
| **Base total** | **~$83** |
| + Prometheus/Grafana (ECS) | ~$30 |
| + ElastiCache Redis | ~$12 |

Set `enable_nat_gateway = false` and `db_multi_az = false` for dev/test to reduce costs.

---

## License

[GPL-3.0](LICENSE)

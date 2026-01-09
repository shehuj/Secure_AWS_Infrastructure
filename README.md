# Secure AWS Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.7+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![Ansible](https://img.shields.io/badge/Ansible-Automation-EE0000?logo=ansible)](https://www.ansible.com/)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

A production-ready, secure AWS infrastructure deployment using Infrastructure as Code (IaC) with Terraform and configuration management with Ansible. This project implements AWS best practices, security controls, and automated CI/CD pipelines.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security](#security)
- [Monitoring](#monitoring)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Features

### Infrastructure Components

- **VPC Module**: Complete networking setup with public and private subnets across multiple AZs
  - Internet Gateway for public subnet connectivity
  - NAT Gateways for private subnet outbound traffic
  - VPC Flow Logs for network monitoring
  - Configurable CIDR blocks and subnet counts

- **EC2 Module**: Secure compute instances with best practices
  - Latest Amazon Linux 2023 AMI (auto-updated)
  - IAM instance profiles with SSM and CloudWatch access
  - Security groups with restricted access
  - IMDSv2 enforcement
  - Encrypted EBS volumes
  - CloudWatch agent for custom metrics

- **Monitoring Module**: Comprehensive observability
  - CloudWatch Alarms for CPU, memory, disk, and status checks
  - Custom CloudWatch Dashboard
  - Centralized log collection
  - SNS notifications for alerts

- **OIDC Module**: Secure GitHub Actions integration
  - OIDC provider for passwordless authentication
  - Fine-grained IAM permissions
  - No long-lived credentials required

### Security Features

- Encrypted data at rest (EBS volumes, S3 state)
- Encrypted data in transit (HTTPS, TLS)
- No SSH keys in code or secrets
- Security group rules following least privilege
- VPC Flow Logs enabled
- CloudWatch logging for all services
- AWS Systems Manager for secure instance access
- Automated security scanning (tfsec, Checkov, Trivy)
- Secret detection with Gitleaks

### Automation & CI/CD

- **Terraform Workflows**:
  - Automated validation and linting
  - Plan on pull requests with detailed output
  - Manual approval gates for apply
  - State locking with DynamoDB

- **Security Scanning**:
  - Weekly automated scans
  - Multiple security tools (tfsec, Checkov, Trivy)
  - SARIF integration with GitHub Security tab
  - Ansible linting with ansible-lint

- **Ansible Deployment**:
  - Automated server configuration
  - Dynamic inventory from AWS
  - Idempotent playbooks
  - Health check validation

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Account                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                   │ │
│  │                                                         │ │
│  │  ┌──────────────────┐     ┌──────────────────┐        │ │
│  │  │  Public Subnet   │     │  Public Subnet   │        │ │
│  │  │  10.0.0.0/24     │     │  10.0.1.0/24     │        │ │
│  │  │  ┌────────────┐  │     │  ┌────────────┐  │        │ │
│  │  │  │   EC2      │  │     │  │  NAT GW    │  │        │ │
│  │  │  │  Web Server│  │     │  └────────────┘  │        │ │
│  │  │  └────────────┘  │     │                  │        │ │
│  │  └──────────────────┘     └──────────────────┘        │ │
│  │           │                        │                   │ │
│  │  ┌────────▼────────────────────────▼───────────┐      │ │
│  │  │          Internet Gateway                   │      │ │
│  │  └─────────────────────────────────────────────┘      │ │
│  │                                                         │ │
│  │  ┌──────────────────┐     ┌──────────────────┐        │ │
│  │  │ Private Subnet   │     │ Private Subnet   │        │ │
│  │  │  10.0.2.0/24     │     │  10.0.3.0/24     │        │ │
│  │  └──────────────────┘     └──────────────────┘        │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                CloudWatch Monitoring                   │ │
│  │  • Dashboards  • Alarms  • Logs  • Metrics            │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘

         │
         │  GitHub Actions (OIDC)
         ▼
┌──────────────────┐
│  GitHub Repo     │
│  CI/CD Pipeline  │
└──────────────────┘
```

## Prerequisites

### Required Tools

- [AWS CLI](https://aws.amazon.com/cli/) v2.x
- [Terraform](https://www.terraform.io/downloads) v1.7+
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) v2.14+
- [Python](https://www.python.org/downloads/) 3.8+
- [jq](https://stedolan.github.io/jq/) (optional, for JSON parsing)

### AWS Account Setup

1. **AWS Account** with appropriate permissions
2. **AWS CLI configured** with credentials
3. **SSH Key Pair** created in your target AWS region

### GitHub Repository Setup

1. Fork or clone this repository
2. Configure GitHub Secrets (see [Configuration](#configuration))

## Quick Start

### 1. Bootstrap Backend Infrastructure

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Run the bootstrap script
./scripts/bootstrap.sh \
  --bucket your-terraform-state-bucket \
  --table terraform-locks \
  --environment prod \
  --region us-east-1
```

This script will:
- Create an S3 bucket with versioning and encryption
- Create a DynamoDB table for state locking
- Generate a backend configuration file

### 2. Configure Terraform Variables

Copy the example tfvars file and customize it:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Required variables
github_repo            = "your-org/your-repo"
key_pair_name         = "your-ssh-key"
terraform_state_bucket = "your-terraform-state-bucket"

# Optional: Customize infrastructure
environment           = "prod"
aws_region           = "us-east-1"
vpc_cidr             = "10.0.0.0/16"
instance_type        = "t3.micro"
instance_count       = 1

# Security: Restrict SSH access
allowed_ssh_cidr = ["YOUR_IP_ADDRESS/32"]
```

### 3. Deploy Infrastructure

#### Option A: Manual Deployment

```bash
cd terraform

# Initialize Terraform
terraform init -backend-config=backend-config.hcl

# Review the plan
terraform plan

# Apply changes
terraform apply
```

#### Option B: Automated Deployment (GitHub Actions)

1. Push your changes to a feature branch
2. Create a pull request to `main`
3. Review the Terraform plan in PR comments
4. Merge PR to trigger automated deployment

### 4. Configure Servers with Ansible

After infrastructure deployment:

```bash
cd ansible

# Test connectivity
ansible all -m ping

# Deploy web server configuration
ansible-playbook playbooks/webserver.yml
```

## Configuration

### GitHub Secrets

Configure these secrets in your GitHub repository:

| Secret Name | Description | Required |
|-------------|-------------|----------|
| `AWS_ROLE_ARN` | ARN of the OIDC IAM role | Yes |
| `AWS_REGION` | AWS region (default: us-east-1) | No |
| `SNYK_TOKEN` | Snyk API token for scanning | No |
| `SONAR_TOKEN` | SonarCloud token | No |

### Terraform Variables

All available variables are documented in [`terraform/variables.tf`](terraform/variables.tf).

Key variables:

- **General**: `environment`, `aws_region`, `tags`
- **VPC**: `vpc_cidr`, `public_subnet_count`, `private_subnet_count`
- **EC2**: `instance_type`, `instance_count`, `allowed_ssh_cidr`
- **Monitoring**: `cpu_threshold`, `memory_threshold`, `alarm_email_endpoints`

## Deployment

### Environment-Specific Deployments

This infrastructure supports multiple environments (dev, staging, prod):

```bash
# Dev environment
terraform workspace new dev
terraform apply -var="environment=dev" -var="instance_type=t3.micro"

# Staging environment
terraform workspace new staging
terraform apply -var="environment=staging" -var="instance_type=t3.small"

# Production environment
terraform workspace new prod
terraform apply -var="environment=prod" -var="instance_type=t3.medium"
```

### Manual Approval Gates

For production deployments, the GitHub Actions workflow includes manual approval:

1. Workflow runs `terraform plan`
2. Waits for manual approval in GitHub UI
3. Only proceeds with `terraform apply` after approval

## CI/CD Pipeline

### Workflow Triggers

- **Terraform Plan**: Runs on pull requests to `main`
- **Terraform Apply**: Runs on push to `main` branch
- **Security Scan**: Runs weekly and on all PRs
- **Ansible Deploy**: Triggered after successful Terraform apply

### Security Scanning Tools

- **tfsec**: Terraform security scanner
- **Checkov**: Policy-as-code scanner
- **Trivy**: Vulnerability scanner
- **ansible-lint**: Ansible best practices
- **Gitleaks**: Secret detection

### Pipeline Stages

1. **Validate**: Terraform fmt, validate, and lint
2. **Security Scan**: Multiple security tools
3. **Plan**: Generate and review Terraform plan
4. **Approval**: Manual approval gate (production)
5. **Apply**: Deploy infrastructure changes
6. **Configure**: Run Ansible playbooks
7. **Verify**: Health checks and smoke tests

## Security

### Best Practices Implemented

- ✅ Encryption at rest (EBS, S3)
- ✅ Encryption in transit (TLS/HTTPS)
- ✅ No hardcoded secrets
- ✅ Least privilege IAM policies
- ✅ Security groups with restricted access
- ✅ VPC Flow Logs enabled
- ✅ CloudWatch logging
- ✅ IMDSv2 enforcement
- ✅ Automated security scanning
- ✅ Regular dependency updates

### Security Recommendations

1. **SSH Access**: Always restrict `allowed_ssh_cidr` to your IP
2. **State Security**: Enable S3 bucket versioning and MFA delete
3. **Secrets Management**: Use AWS Secrets Manager for sensitive data
4. **Monitoring**: Set up SNS notifications for security alarms
5. **Compliance**: Review weekly security scan reports

## Monitoring

### CloudWatch Dashboard

Access the CloudWatch dashboard:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=prod-infrastructure-dashboard
```

### Available Metrics

- CPU Utilization
- Memory Utilization (custom metric)
- Disk Utilization (custom metric)
- Network In/Out
- Status Checks

### Alarms

Configured alarms:
- High CPU usage (> 80%)
- High memory usage (> 80%)
- High disk usage (> 80%)
- Instance status check failures

### Logs

Log groups:
- `/aws/ec2/{environment}/nginx/access`
- `/aws/ec2/{environment}/nginx/error`
- `/aws/vpc/{environment}-flow-logs`

## Cost Optimization

### Estimated Monthly Costs

- **t3.micro instances** (2): ~$15/month
- **NAT Gateway** (1): ~$32/month
- **EBS volumes** (20GB): ~$2/month
- **Data transfer**: Variable
- **CloudWatch**: ~$5/month

**Total**: ~$54/month (single NAT, 2 instances)

### Cost Saving Tips

1. Use `single_nat_gateway = true` (enabled by default)
2. Use Spot instances for dev/staging
3. Stop instances when not in use
4. Use AWS Cost Explorer for analysis
5. Set up billing alerts

## Troubleshooting

### Common Issues

#### 1. Terraform Init Fails

```bash
# Ensure backend bucket exists
aws s3 ls s3://your-terraform-state-bucket

# Run bootstrap script if needed
./scripts/bootstrap.sh -b your-terraform-state-bucket
```

#### 2. EC2 Instances Not Accessible

```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Verify instance is running
aws ec2 describe-instances --instance-ids i-xxxxx
```

#### 3. Ansible Cannot Connect

```bash
# Test AWS credentials
aws sts get-caller-identity

# Verify dynamic inventory
ansible-inventory -i inventory/aws_ec2.yml --list

# Use SSM for access (no SSH key needed)
aws ssm start-session --target i-xxxxx
```

### Getting Help

- Check [GitHub Issues](../../issues)
- Review [Terraform Registry Docs](https://registry.terraform.io/)
- AWS Support

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

Please follow:
- [Terraform Style Guide](https://www.terraform.io/docs/language/syntax/style.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- HashiCorp for Terraform
- Red Hat for Ansible
- AWS for cloud infrastructure
- Security scanning tools: tfsec, Checkov, Trivy

---

**Made with ❤️ for secure and automated infrastructure deployment**

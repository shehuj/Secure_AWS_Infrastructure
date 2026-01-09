# Infrastructure Idempotency Guide

This document explains how idempotency is implemented across the Secure AWS Infrastructure project and how to maintain it.

## Table of Contents

1. [What is Idempotency?](#what-is-idempotency)
2. [Terraform Idempotency](#terraform-idempotency)
3. [Ansible Idempotency](#ansible-idempotency)
4. [CI/CD Idempotency](#cicd-idempotency)
5. [Testing Idempotency](#testing-idempotency)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

## What is Idempotency?

**Idempotency** means that applying the same operation multiple times produces the same result as applying it once. In infrastructure as code:

- Running `terraform apply` twice should result in "no changes" on the second run
- Running an Ansible playbook twice should make changes only on the first run
- Workflows should detect when no changes are needed and skip unnecessary operations

### Why Idempotency Matters

1. **Safety**: Prevents unintended changes to production infrastructure
2. **Reliability**: Ensures consistent state regardless of how many times operations run
3. **Efficiency**: Avoids wasting resources on unnecessary updates
4. **Predictability**: Makes infrastructure behavior deterministic

## Terraform Idempotency

### Lifecycle Rules

Terraform resources use lifecycle blocks to control how changes are applied:

```hcl
resource "aws_instance" "web" {
  # ... configuration ...

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false  # Set to true in production

    ignore_changes = [
      ami,                    # Ignore AMI updates
      user_data,              # Changes managed by Ansible
      tags["Created"],        # Ignore AWS-managed tags
      tags["Modified"]
    ]
  }
}
```

#### Key Lifecycle Directives

| Directive | Purpose | Example Use Case |
|-----------|---------|------------------|
| `prevent_destroy` | Prevents accidental deletion | Production databases, VPCs |
| `create_before_destroy` | Creates new before deleting old | Zero-downtime replacements |
| `ignore_changes` | Ignores specific attribute changes | Dynamic tags, managed configs |

### State Locking

State locking prevents concurrent modifications:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "prod/terraform.tfstate"
    dynamodb_table = "terraform-locks"  # Enables locking
    encrypt        = true
  }
}
```

### Version Pinning

Ensures consistent Terraform behavior:

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow patch updates only
    }
  }
}
```

### Preventing Drift

Idempotency can be compromised by state drift (manual changes outside Terraform):

**Detection:**
```bash
terraform plan  # Shows any drift from expected state
```

**Prevention:**
- Use AWS Service Control Policies (SCPs) to limit manual changes
- Enable CloudTrail for audit logging
- Run regular drift detection in CI/CD

## Ansible Idempotency

### Idempotent Modules

Ansible modules are generally idempotent by default, but some require careful configuration:

#### Good: Idempotent by Default

```yaml
- name: Install nginx
  yum:
    name: nginx
    state: present  # Only installs if not present
```

#### Requires Care: Shell/Command

```yaml
# NOT idempotent
- name: Create file
  shell: echo "hello" > /tmp/file.txt

# Idempotent
- name: Create file
  copy:
    content: "hello"
    dest: /tmp/file.txt
  # Only changes if content differs
```

### Changed_when Directive

Controls when tasks report changes:

```yaml
- name: Health check
  uri:
    url: "http://localhost/health"
  register: health
  changed_when: false  # Never reports changed
  failed_when: health.status != 200
```

### Check Mode

Test idempotency without making changes:

```bash
ansible-playbook playbook.yml --check --diff
```

### Handlers

Handlers only run when notified, preventing unnecessary service restarts:

```yaml
tasks:
  - name: Update nginx config
    copy:
      src: nginx.conf
      dest: /etc/nginx/nginx.conf
    notify: Restart nginx

handlers:
  - name: Restart nginx
    systemd:
      name: nginx
      state: restarted
```

## CI/CD Idempotency

### GitHub Actions Workflows

#### Change Detection

Workflows only run when relevant files change:

```yaml
on:
  push:
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-*.yml'
```

#### Conditional Execution

Jobs check for actual changes before running:

```yaml
jobs:
  apply:
    steps:
      - name: Check for changes
        run: terraform plan -detailed-exitcode
        # Exit code 2 = changes detected
        
      - name: Apply changes
        if: steps.plan.outputs.exitcode == '2'
        run: terraform apply
```

#### Idempotent Deployments

The Ansible workflow checks infrastructure state first:

```yaml
jobs:
  check-infrastructure:
    steps:
      - name: Check for instances
        run: |
          aws ec2 describe-instances \
            --filters "Name=tag:Role,Values=web" \
            --query 'Reservations[].Instances[].InstanceId'
  
  deploy:
    needs: check-infrastructure
    if: needs.check-infrastructure.outputs.instances_exist == 'true'
```

## Testing Idempotency

### Automated Tests

Run the idempotency test suite:

```bash
./scripts/test-idempotency.sh
```

This tests:
1. Terraform plan produces no changes on re-run
2. Ansible playbook shows no changes on second run
3. State file consistency
4. No unexpected resource replacements
5. Configuration validation

### Manual Testing

#### Terraform

```bash
# First run
terraform apply

# Second run - should show "No changes"
terraform plan
# Expected: "No changes. Infrastructure is up-to-date."
```

#### Ansible

```bash
# First run
ansible-playbook playbooks/webserver.yml

# Second run - should show 0 changed tasks
ansible-playbook playbooks/webserver.yml
# Expected: "changed=0"
```

### CI/CD Testing

Workflows automatically run check mode before applying changes:

```yaml
- name: Dry run
  run: ansible-playbook playbooks/webserver.yml --check --diff

- name: Actual run
  run: ansible-playbook playbooks/webserver.yml --diff
```

## Best Practices

### 1. Use Declarative Configuration

❌ **Imperative (Not Idempotent)**:
```bash
#!/bin/bash
aws ec2 run-instances --image-id ami-123 --count 1
```

✅ **Declarative (Idempotent)**:
```hcl
resource "aws_instance" "web" {
  ami           = "ami-123"
  instance_type = "t3.micro"
  count         = 1
}
```

### 2. Avoid Hardcoded Values

Use variables and data sources:

```hcl
# Get latest AMI
data "aws_ami" "latest" {
  most_recent = true
  owners      = ["amazon"]
  # ...
}

resource "aws_instance" "web" {
  ami = data.aws_ami.latest.id  # Dynamic value
}
```

### 3. Use State Management

- Always use remote state (S3) with locking (DynamoDB)
- Never edit state files manually
- Use `terraform import` for existing resources

### 4. Handle External Changes

Use `ignore_changes` for attributes managed outside Terraform:

```hcl
lifecycle {
  ignore_changes = [
    tags["LastBackup"],  # Updated by backup system
    user_data           # Managed by configuration management
  ]
}
```

### 5. Document Assumptions

```hcl
# This resource assumes:
# - VPC already exists (created separately)
# - Route53 zone is managed manually
# - AMI is updated monthly via separate process
```

### 6. Use Makefile for Consistency

```bash
make plan   # Always runs validation first
make apply  # Always requires plan
make test   # Runs idempotency tests
```

## Troubleshooting

### Problem: Terraform Shows Changes on Every Run

**Symptoms:**
```
# aws_instance.web will be updated in-place
~ tags = {
    ~ "LastModified" = "2024-01-01" -> "2024-01-02"
  }
```

**Solution:**
```hcl
lifecycle {
  ignore_changes = [tags["LastModified"]]
}
```

### Problem: Ansible Always Shows "Changed"

**Symptoms:**
```
TASK [Create file] ****
changed: [host]

# Second run
changed: [host]  # Should be "ok"
```

**Solutions:**

1. Use appropriate modules:
   ```yaml
   # Instead of shell/command
   - shell: echo "hello" > file.txt
   
   # Use copy/template
   - copy:
       content: "hello"
       dest: file.txt
   ```

2. Add `changed_when`:
   ```yaml
   - shell: some-command
     changed_when: result.stdout != "already exists"
   ```

### Problem: State Drift

**Detection:**
```bash
terraform plan
# Shows unexpected changes
```

**Solutions:**

1. **Import manual changes:**
   ```bash
   terraform import aws_instance.web i-1234567890
   ```

2. **Revert manual changes:**
   ```bash
   terraform apply  # Reverts to Terraform state
   ```

3. **Prevent drift:**
   - Use AWS SCPs to restrict manual changes
   - Enable CloudTrail for audit logs
   - Run automated drift detection

### Problem: Resource Recreation

**Symptoms:**
```
# aws_instance.web must be replaced
-/+ resource "aws_instance" "web" {
```

**Common Causes:**
1. AMI change
2. Instance type change
3. Subnet change

**Solutions:**

1. For planned replacements:
   ```hcl
   lifecycle {
     create_before_destroy = true
   }
   ```

2. To ignore changes:
   ```hcl
   lifecycle {
     ignore_changes = [ami]
   }
   ```

## Verification Checklist

Use this checklist to verify idempotency:

### Terraform
- [ ] Second `terraform plan` shows no changes
- [ ] State locking is configured (DynamoDB)
- [ ] Lifecycle rules are defined for critical resources
- [ ] Version constraints are set
- [ ] No hardcoded values (use variables/data sources)

### Ansible
- [ ] Second playbook run shows `changed=0`
- [ ] Check mode (`--check`) works without errors
- [ ] All tasks use idempotent modules
- [ ] `changed_when` is used where needed
- [ ] Handlers are used for restarts

### CI/CD
- [ ] Workflows detect when no changes are needed
- [ ] Plan is generated before apply
- [ ] Manual approval is required for production
- [ ] Automated tests verify idempotency

### Testing
- [ ] `make idempotency-test` passes
- [ ] Manual testing confirms no changes on re-run
- [ ] Drift detection is working

## Additional Resources

- [Terraform Lifecycle Meta-Argument](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [HashiCorp Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

**Last Updated**: January 2026  
**Maintained By**: DevOps Team

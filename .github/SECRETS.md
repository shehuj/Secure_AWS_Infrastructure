# GitHub Secrets Configuration

This document lists all secrets required for GitHub Actions workflows.

## Required Secrets

These secrets are **required** for workflows to function:

| Secret Name | Description | Used By | How to Get |
|-------------|-------------|---------|------------|
| `AWS_ACCESS_KEY_ID` | AWS access key | All AWS workflows | [AWS Console](https://console.aws.amazon.com/iam) → Users → Security credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | All AWS workflows | Same as above |
| `GITHUB_TOKEN` | GitHub API token | All workflows | **Automatic** - provided by GitHub |

### Setup Instructions

1. **Create IAM User in AWS:**
   ```bash
   # Required permissions:
   - AmazonEC2FullAccess (or more restrictive custom policy)
   - IAMFullAccess (or more restrictive custom policy)
   - AmazonS3FullAccess (or more restrictive custom policy)
   ```

2. **Add to GitHub:**
   - Go to: Repository → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Add both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

---

## Optional Secrets

These secrets enable **additional features** but are not required:

### Security Scanning

| Secret Name | Purpose | Setup Guide |
|-------------|---------|-------------|
| `SNYK_TOKEN` | Snyk IaC scanning | [docs/SECURITY_TOOLS_SETUP.md](../docs/SECURITY_TOOLS_SETUP.md#1-snyk-optional) |
| `SONAR_TOKEN` | SonarCloud code analysis | [docs/SECURITY_TOOLS_SETUP.md](../docs/SECURITY_TOOLS_SETUP.md#2-sonarcloud-optional) |

**If not configured:** These tools will be automatically skipped during security scans.

### Notifications

| Secret Name | Purpose | Setup |
|-------------|---------|-------|
| `SLACK_WEBHOOK` | Slack notifications for deployments | Slack → Apps → Incoming Webhooks |

**If not configured:** Notification steps will be skipped.

### Advanced Features

| Secret Name | Purpose | Setup |
|-------------|---------|-------|
| `AWS_PROD_ROLE_ARN` | Production environment IAM role | AWS IAM → Roles → Copy ARN |
| `SSH_PRIVATE_KEY` | Ansible SSH authentication | Your private SSH key |
| `SSH_PRIVATE_KEY_PROD` | Production SSH key | Your production SSH key |
| `PAT_TOKEN` | Personal Access Token for dependency updates | GitHub Settings → Developer settings → Personal access tokens |
| `PROD_APPROVERS` | Production deployment approvers | Comma-separated GitHub usernames |

**If not configured:**
- Production will use same credentials as staging
- Ansible will use SSH agent or key files
- Dependency updates will use GITHUB_TOKEN
- Manual approval will use default reviewers

---

## Security Best Practices

### 1. Principle of Least Privilege

Create IAM users with minimal required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "elasticloadbalancing:*",
        "iam:PassRole",
        "logs:*",
        "codedeploy:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. Rotate Secrets Regularly

- AWS keys: Every 90 days
- API tokens: Every 90 days
- SSH keys: Every 180 days

### 3. Use Environment Secrets

For environment-specific secrets:
- Settings → Environments → {environment} → Add secret

### 4. Monitor Secret Usage

- Check Actions logs for unauthorized access attempts
- Enable AWS CloudTrail
- Review audit logs regularly

### 5. Never Commit Secrets

Pre-commit hooks will catch secrets, but:
- Never hardcode secrets
- Use `.env.example` files without real values
- Always use GitHub Secrets or AWS Secrets Manager

---

## Workflow-Specific Requirements

### terraform-ci-cd.yml
**Required:**
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

**Optional:**
- AWS_PROD_ROLE_ARN (for production)
- SLACK_WEBHOOK (for notifications)

### ansible-ci-cd.yml
**Required:**
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

**Optional:**
- SSH_PRIVATE_KEY
- AWS_PROD_ROLE_ARN
- SLACK_WEBHOOK

### blue-green-deployment.yml
**Required:**
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

**Optional:**
- AWS_PROD_ROLE_ARN
- SLACK_WEBHOOK

### security-scan.yml
**Required:**
- GITHUB_TOKEN (automatic)

**Optional:**
- SNYK_TOKEN
- SONAR_TOKEN

### pr-validation.yml
**Required:**
- GITHUB_TOKEN (automatic)

**Optional:**
- None

### dependency-update.yml
**Required:**
- GITHUB_TOKEN (automatic)

**Optional:**
- PAT_TOKEN (for creating PRs from workflows)

---

## Testing Secret Configuration

### 1. Test AWS Credentials

```bash
# Locally
aws sts get-caller-identity

# In GitHub Actions
# Push a commit and check workflow logs
```

### 2. Test Optional Tools

Push a commit and check:
- Actions → Security Scanning
- Look for skipped vs. executed steps

### 3. Verify Permissions

```bash
# Test Terraform
terraform plan

# Test Ansible
ansible-playbook --check playbook.yml
```

---

## Troubleshooting

### "Secret not found" Error

**Cause:** Secret name mismatch

**Solution:**
1. Check exact secret name (case-sensitive)
2. Verify secret exists in repository settings
3. Check if secret is in environment vs. repository

### "Invalid credentials" Error

**Cause:** Incorrect or expired credentials

**Solution:**
1. Regenerate AWS keys
2. Update secret values
3. Ensure IAM user has required permissions

### "Permission denied" Error

**Cause:** Insufficient IAM permissions

**Solution:**
1. Review IAM policy
2. Add required permissions
3. Test with AWS CLI first

---

## Quick Setup Checklist

- [ ] AWS_ACCESS_KEY_ID configured
- [ ] AWS_SECRET_ACCESS_KEY configured
- [ ] Test AWS credentials work
- [ ] (Optional) SNYK_TOKEN for enhanced scanning
- [ ] (Optional) SONAR_TOKEN for code quality
- [ ] (Optional) SLACK_WEBHOOK for notifications
- [ ] (Optional) AWS_PROD_ROLE_ARN for production
- [ ] Secrets tested with workflow run

---

## Additional Resources

- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Security Tools Setup Guide](../docs/SECURITY_TOOLS_SETUP.md)
- [Automation Documentation](../docs/AUTOMATION.md)

---

**Last Updated:** 2026-01-11

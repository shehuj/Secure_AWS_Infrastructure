# Security Tools Setup Guide

This guide explains how to configure optional security scanning tools for enhanced security coverage.

## Overview

The security scanning workflow includes several tools:

### ✅ Always Enabled (No Configuration Required)
- **TruffleHog** - Secret scanning
- **Gitleaks** - Secret leak detection
- **Checkov** - Terraform security scanning
- **tfsec** - Terraform static analysis
- **ansible-lint** - Ansible security checks
- **detect-secrets** - Local secret detection
- **Trivy** - Container vulnerability scanning
- **CodeQL** - Code analysis (GitHub native)

### 🔧 Optional Tools (Require Setup)
- **Snyk** - Infrastructure as Code & dependency scanning
- **SonarCloud** - Code quality and security analysis
- **OWASP Dependency Check** - Dependency vulnerability scanning

## Quick Start

**Good news!** The security workflow works perfectly without configuring optional tools. They will be automatically skipped if not configured.

## Optional Tool Setup

### 1. Snyk (Optional)

Snyk provides advanced IaC scanning and dependency analysis.

#### Setup Steps

1. **Create Snyk Account**
   - Go to https://snyk.io
   - Sign up with GitHub
   - Free tier available

2. **Get API Token**
   - Go to Account Settings → General
   - Copy your API token

3. **Add to GitHub Secrets**
   ```
   Repository → Settings → Secrets and variables → Actions
   Click "New repository secret"
   Name: SNYK_TOKEN
   Value: <your-api-token>
   ```

4. **Verify**
   - Push a commit
   - Check Actions → Security Scanning
   - Snyk step will now run

**Benefits:**
- Advanced vulnerability detection
- License compliance checking
- Dependency graph visualization
- Fix suggestions

**Cost:** Free for open source, paid for private repos

---

### 2. SonarCloud (Optional)

SonarCloud provides comprehensive code quality and security analysis.

#### Setup Steps

1. **Create SonarCloud Account**
   - Go to https://sonarcloud.io
   - Sign up with GitHub
   - Free for public repositories

2. **Import Repository**
   - Click "+" → Analyze new project
   - Select your repository
   - Choose "With GitHub Actions"

3. **Get Token**
   - My Account → Security
   - Generate Token
   - Copy the token

4. **Add to GitHub Secrets**
   ```
   Repository → Settings → Secrets and variables → Actions
   Click "New repository secret"
   Name: SONAR_TOKEN
   Value: <your-token>
   ```

5. **Update sonar-project.properties** (if needed)
   ```properties
   sonar.organization=<your-org>
   sonar.projectKey=<your-project-key>
   ```

6. **Verify**
   - Push a commit
   - Check SonarCloud dashboard
   - View analysis results

**Benefits:**
- Code quality metrics
- Security hotspot detection
- Code smell identification
- Technical debt tracking
- Quality gate enforcement

**Cost:** Free for public repos, paid for private

---

### 3. OWASP Dependency Check (Included)

Already configured! Runs automatically on every scan.

**No setup required.**

---

## GitHub Secrets Reference

Required secrets for full security coverage:

| Secret Name | Required | Used By | How to Get |
|-------------|----------|---------|------------|
| `AWS_ACCESS_KEY_ID` | ✅ Yes | All workflows | AWS Console |
| `AWS_SECRET_ACCESS_KEY` | ✅ Yes | All workflows | AWS Console |
| `GITHUB_TOKEN` | ✅ Auto | All workflows | Automatic |
| `SNYK_TOKEN` | ⚠️ Optional | Security scan | snyk.io |
| `SONAR_TOKEN` | ⚠️ Optional | Security scan | sonarcloud.io |
| `SLACK_WEBHOOK` | ⚠️ Optional | Notifications | Slack |
| `AWS_PROD_ROLE_ARN` | ⚠️ Optional | Production | AWS IAM |
| `SSH_PRIVATE_KEY` | ⚠️ Optional | Ansible | Your SSH key |
| `PAT_TOKEN` | ⚠️ Optional | Dependency updates | GitHub |

### How to Add Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Enter name and value
5. Click **Add secret**

---

## Verifying Setup

### Check Security Workflow

1. Go to **Actions** tab
2. Click on latest **Security Scanning** workflow
3. Check which steps ran:
   - ✅ Green = Ran successfully
   - ⬜ Gray = Skipped (no secret configured)
   - ❌ Red = Failed

### Expected Results

**Without optional tools:**
```
✅ Secret Scanning (TruffleHog, Gitleaks)
✅ Terraform Security (Checkov, tfsec)
✅ Ansible Security
⬜ Dependency Scanning (Snyk skipped)
✅ SAST Scanning (CodeQL)
⬜ SonarCloud (skipped)
✅ Container Scanning
```

**With all tools configured:**
```
✅ Secret Scanning (TruffleHog, Gitleaks)
✅ Terraform Security (Checkov, tfsec)
✅ Ansible Security
✅ Dependency Scanning (Snyk)
✅ SAST Scanning (CodeQL)
✅ SonarCloud
✅ Container Scanning
```

---

## Troubleshooting

### Snyk Fails

**Problem:** "Unauthorized" or "Invalid token"

**Solution:**
1. Verify token is correct
2. Check token hasn't expired
3. Ensure token has correct permissions
4. Re-generate token if needed

### SonarCloud Fails

**Problem:** "Could not find organization"

**Solution:**
1. Verify organization name in `sonar-project.properties`
2. Check you have access to the organization
3. Ensure project is imported in SonarCloud
4. Update SONAR_ORGANIZATION environment variable

### CodeQL Fails

**Problem:** Language not supported

**Solution:**
1. Check `.github/workflows/security-scan.yml`
2. Update languages list:
   ```yaml
   languages: python, javascript, typescript, go
   ```

---

## Local Security Scanning

Run security scans locally before pushing:

### All Security Checks
```bash
make security
```

### Individual Scans
```bash
# Terraform security
make security-terraform

# Ansible security
make security-ansible

# Secret scanning
make security-secrets

# Pre-commit (includes security)
make pre-commit-run
```

---

## Security Best Practices

### 1. Enable All Tools
For maximum security, enable all optional tools:
- Snyk for dependency analysis
- SonarCloud for code quality
- All pre-commit hooks

### 2. Review Scan Results
- Check security tab regularly
- Address high/critical issues
- Track security debt

### 3. Automate Remediation
- Enable Snyk auto-fix PRs
- Use SonarCloud quality gates
- Configure Dependabot

### 4. Regular Audits
- Weekly security reviews
- Monthly compliance checks
- Quarterly security assessments

### 5. Stay Updated
- Enable dependency updates
- Monitor security advisories
- Update scanning tools regularly

---

## Cost Overview

| Tool | Public Repos | Private Repos |
|------|--------------|---------------|
| TruffleHog | Free | Free |
| Gitleaks | Free | Free |
| Checkov | Free | Free |
| tfsec | Free | Free |
| Trivy | Free | Free |
| CodeQL | Free | Free for public |
| **Snyk** | **Free** | **Paid** |
| **SonarCloud** | **Free** | **Paid** |
| OWASP | Free | Free |

**Recommendation:**
- Public repos: Enable everything (all free!)
- Private repos: Start with free tools, add paid tools as needed

---

## Support

### Documentation
- [Automation Guide](./AUTOMATION.md)
- [Blue-Green Deployment](./BLUE_GREEN_DEPLOYMENT.md)
- [Troubleshooting Guide](./AUTOMATION.md#troubleshooting)

### External Resources
- Snyk: https://docs.snyk.io
- SonarCloud: https://docs.sonarcloud.io
- CodeQL: https://codeql.github.com/docs

### Getting Help
- Check GitHub Actions logs
- Review security scan reports
- Open an issue in the repository

---

## Summary

✅ **Default Setup** works perfectly without optional tools
✅ **Optional Tools** enhance security coverage
✅ **Easy Configuration** - just add secrets
✅ **No Breaking Changes** - tools are skipped if not configured
✅ **Production Ready** - comprehensive security by default

**You're already secure!** Optional tools provide additional coverage.

---

**Last Updated:** 2026-01-11
**Version:** 1.0.0

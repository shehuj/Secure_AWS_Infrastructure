# Ghost Deployment Issues and Fixes

## Date: 2026-01-11

## Summary
Fixed critical issues preventing Ghost blog from being accessible on claudiq.com.

---

## Issues Found

### 1. ❌ Container Health Check Failure (CRITICAL)
**Problem**: ECS containers continuously failing health checks and restarting every ~18 minutes.

**Root Cause**:
- Ghost is configured for HTTPS (url: https://claudiq.com)
- When accessed via HTTP, Ghost returns 301 redirect
- Container health check used `curl -f` which treats 301 as failure
- ALB target group health check accepts 301, but container health check did not

**Evidence**:
```
[2026-01-11 16:31:19] INFO "GET /" 301 1ms
[2026-01-11 16:33:43] WARN Ghost is shutting down
[2026-01-11 16:33:43] WARN Ghost has shut down
[2026-01-11 16:33:43] WARN Your site is now offline
[2026-01-11 16:33:43] WARN Ghost was running for 18 minutes
```

**Fix Applied**:
- Changed health check command from `curl -f http://localhost:2368/` to:
  ```bash
  curl -s -o /dev/null -w '%%{http_code}' http://localhost:2368/ | grep -E '^(200|301)$' || exit 1
  ```
- Now accepts both 200 OK and 301 Moved Permanently as healthy responses

**Location**: `terraform/modules/ecs_ghost/main.tf:266`

---

### 2. ❌ DNS Misconfiguration (CRITICAL)
**Problem**: Domain claudiq.com not resolving to the correct ALB.

**Root Cause**:
- Route 53 A record points to: `prod-ghost-alb-1366014259.us-east-1.elb.amazonaws.com` (OLD)
- Actual running ALB DNS is: `prod-ghost-alb-1152946560.us-east-1.elb.amazonaws.com` (CURRENT)
- ALB was likely recreated but DNS wasn't updated

**Evidence**:
```bash
# Current ALB
aws elbv2 describe-load-balancers
DNS: prod-ghost-alb-1152946560.us-east-1.elb.amazonaws.com

# Route 53 record (incorrect)
aws route53 list-resource-record-sets
claudiq.com -> prod-ghost-alb-1366014259.us-east-1.elb.amazonaws.com
```

**Fix Applied**:
- Added Terraform resources to automatically manage Route 53 records
- Created `aws_route53_record.ghost` for apex domain
- Created `aws_route53_record.ghost_www` for www subdomain
- Both use alias records pointing to ALB DNS with health check evaluation

**Location**: `terraform/modules/ecs_ghost/main.tf:443-473`

---

## Current Status

### ✅ ALB Health
- **Status**: Active and healthy
- **Targets**: 3 healthy targets (10.0.0.96, 10.0.1.132, 10.0.0.117)
- **DNS**: prod-ghost-alb-1152946560.us-east-1.elb.amazonaws.com
- **Target Group**: All targets passing health checks (accepts 200,301)

### ⚠️ Container Health
- **Status**: Currently UNHEALTHY (will be fixed after Terraform apply)
- **Tasks**: Continuously restarting due to failed health checks
- **Reason**: Health check rejects 301 redirects

### ❌ Domain Access
- **Status**: Not accessible at claudiq.com
- **Reason**: DNS points to wrong ALB
- **ALB Direct Access**: Working at ALB DNS

---

## Required Actions

### 1. Apply Terraform Changes
```bash
cd terraform
terraform init
terraform plan -target=module.ghost_blog
terraform apply -target=module.ghost_blog
```

**Expected Changes**:
- Update ECS task definition with new health check
- Create Route 53 A records for claudiq.com and www.claudiq.com
- Force new deployment of ECS service

### 2. Verify Health After Apply
```bash
# Check container health (should be HEALTHY after ~2 minutes)
aws ecs list-tasks --cluster prod-ghost-cluster --service-name prod-ghost-service --desired-status RUNNING | \
  jq -r '.taskArns[0]' | \
  xargs -I {} aws ecs describe-tasks --cluster prod-ghost-cluster --tasks {} \
  --query 'tasks[0].healthStatus'

# Expected: "HEALTHY"
```

### 3. Verify DNS Propagation
```bash
# Check DNS resolution (may take 5-15 minutes)
dig +short claudiq.com

# Expected: IP addresses of ALB
```

### 4. Test Website Access
```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://claudiq.com

# Test HTTPS
curl -I https://claudiq.com

# Expected: 200 OK or valid Ghost response
```

---

## Additional Improvements Made

### GitHub Actions Workflows

#### 1. Compliance Workflow
- **File**: `.github/workflows/compliance.yml:40`
- **Fix**: Added `github_token: ${{ secrets.GITHUB_TOKEN }}` to tfsec action
- **Reason**: Prevents GitHub API rate limiting

#### 2. Ghost Deploy Workflow
- **File**: `.github/workflows/ghost-deploy.yml`
- **Major Enhancements**:
  - ✅ Auto-recreate inactive ECS clusters with Terraform
  - ✅ Comprehensive error handling with retries
  - ✅ Automated rollback on deployment failure
  - ✅ Slack notifications (optional, requires SLACK_WEBHOOK_URL)
  - ✅ PR comments with deployment status
  - ✅ Timeout handling (Docker build, ECR push, service updates)
  - ✅ Health verification after deployment
  - ✅ Detailed summaries at each stage

---

## Monitoring

### Check Container Logs
```bash
aws logs tail /ecs/prod/ghost --since 30m --follow
```

### Check ECS Service Events
```bash
aws ecs describe-services \
  --cluster prod-ghost-cluster \
  --services prod-ghost-service \
  --query 'services[0].events[0:10]' \
  --output table
```

### Check ALB Target Health
```bash
aws elbv2 describe-target-groups \
  --query 'TargetGroups[?contains(TargetGroupName, `ghost`)].TargetGroupArn' \
  --output text | \
  xargs -I {} aws elbv2 describe-target-health \
  --target-group-arn {} --output table
```

---

## Files Modified

1. `terraform/modules/ecs_ghost/main.tf`
   - Line 266: Fixed container health check
   - Lines 443-473: Added Route 53 DNS management

2. `.github/workflows/compliance.yml`
   - Line 40: Added github_token to tfsec

3. `.github/workflows/ghost-deploy.yml`
   - Complete rewrite with enterprise-grade features

---

## Expected Timeline

1. **Immediate** (0-5 min): Apply Terraform changes
2. **Short-term** (5-15 min): Containers become healthy, new tasks stable
3. **DNS Propagation** (15-60 min): Domain accessible globally
4. **Ghost Setup** (if first deploy): Complete setup at https://claudiq.com/ghost/

---

## Support

If issues persist after applying fixes:

1. Check CloudWatch Logs: `/ecs/prod/ghost`
2. Verify certificate: `aws acm describe-certificate --certificate-arn <ARN>`
3. Check security groups: Ensure port 443 allows inbound traffic
4. Review ECS service events for errors
5. Verify EFS mount is working (Ghost content storage)

---

## Configuration Summary

- **Environment**: prod
- **Domain**: claudiq.com
- **Ghost Version**: latest
- **ECS Cluster**: prod-ghost-cluster
- **ECS Service**: prod-ghost-service
- **Desired Tasks**: 2
- **CPU**: 512
- **Memory**: 1024 MB
- **Storage**: EFS (encrypted, mounted at /var/lib/ghost/content)
- **Database**: SQLite3 (file-based on EFS)
- **ALB**: prod-ghost-alb
- **Target Group**: prod-ghost-tg (health check accepts 200,301)

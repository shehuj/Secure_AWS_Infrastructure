# Blue-Green Deployment for ECS

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Terraform Module](#terraform-module)
- [Deployment Scripts](#deployment-scripts)
- [Usage Examples](#usage-examples)
- [Advanced Topics](#advanced-topics)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

This implementation provides **zero-downtime blue-green deployments** for ECS Fargate applications using AWS CodeDeploy.

### What is Blue-Green Deployment?

Blue-green deployment is a release management strategy that reduces downtime and risk by running two identical production environments:

- **Blue**: Current production environment
- **Green**: New version being deployed

Traffic is shifted from blue to green once the new version is validated, enabling instant rollback if issues arise.

### Key Features

✅ **Zero Downtime** - No service interruption during deployments
✅ **Instant Rollback** - Revert to previous version in seconds
✅ **Automated Testing** - Test new version before production traffic
✅ **Traffic Shifting** - Gradual or all-at-once traffic migration
✅ **Auto Rollback** - Automatic rollback on deployment failure
✅ **Full Observability** - CloudWatch logs and metrics
✅ **Security** - HTTPS/TLS, security groups, IAM roles

## Architecture

### High-Level Architecture

```
┌────────────────────────────────────────────────────────────┐
│                   Application Load Balancer                 │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │  Listener :443   │         │  Listener :8443  │         │
│  │  (Production)    │         │  (Test)          │         │
│  └────────┬─────────┘         └────────┬─────────┘         │
└───────────┼──────────────────────────────┼─────────────────┘
            │                              │
            ├──────────────┬───────────────┤
            │              │               │
     ┌──────▼──────┐  ┌───▼──────┐   ┌───▼──────┐
     │  Blue TG    │  │ Green TG │   │ Green TG │
     │  (Active)   │  │ (Standby)│   │ (Testing)│
     └──────┬──────┘  └───┬──────┘   └───┬──────┘
            │             │              │
       ┌────▼─────┐  ┌────▼─────┐   ┌───▼──────┐
       │   ECS    │  │   ECS    │   │   ECS    │
       │  Tasks   │  │  Tasks   │   │  Tasks   │
       │  (v1.0)  │  │  (v2.0)  │   │  (v2.0)  │
       └──────────┘  └──────────┘   └──────────┘
```

### Deployment Flow

```
1. Register new task definition (v2.0)
2. Deploy green environment with new version
3. Test green environment via test listener (:8443)
4. Shift production traffic from blue to green
5. Monitor green environment
6. Terminate blue environment (v1.0)
7. Green becomes new blue (v2.0)
```

### Component Breakdown

| Component | Purpose |
|-----------|---------|
| **ECS Cluster** | Hosts Fargate tasks |
| **Blue Target Group** | Current production tasks |
| **Green Target Group** | New version tasks |
| **ALB Production Listener** | Routes production traffic (443) |
| **ALB Test Listener** | Routes test traffic (8443) |
| **CodeDeploy** | Orchestrates blue-green deployment |
| **CloudWatch Logs** | Application and deployment logs |
| **IAM Roles** | ECS task and CodeDeploy permissions |

## Quick Start

### Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Valid ACM certificate
- VPC with public subnets

### 1. Deploy Infrastructure

```bash
# Navigate to terraform directory
cd terraform

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
environment          = "prod"
app_name             = "webapp"
container_image      = "nginx:latest"
certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
vpc_id               = "vpc-xxxxx"
subnet_ids           = ["subnet-xxxxx", "subnet-yyyyy"]
EOF

# Initialize and apply
terraform init
terraform plan
terraform apply
```

### 2. Deploy New Version

```bash
# Deploy new container image
./scripts/blue-green/deploy.sh \
  -e prod \
  -a webapp \
  -i nginx:1.21
```

### 3. Monitor Deployment

```bash
# Watch deployment progress
./scripts/blue-green/status.sh -e prod -a webapp --watch
```

### 4. Rollback (if needed)

```bash
# Rollback to previous version
./scripts/blue-green/rollback.sh -e prod -a webapp
```

## Terraform Module

### Module Usage

```hcl
module "blue_green_deployment" {
  source = "./modules/ecs_bluegreen"

  environment   = "prod"
  app_name      = "webapp"
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.public_subnet_ids
  certificate_arn = aws_acm_certificate.main.arn

  # Container configuration
  container_image = "nginx:latest"
  container_port  = 80
  cpu             = 256
  memory          = 512
  desired_count   = 2

  # Health check
  health_check_path    = "/"
  health_check_matcher = "200,301"

  # Deployment configuration
  deployment_timeout_minutes        = 10
  termination_wait_time_minutes     = 5
  enable_auto_rollback              = true

  # Optional: Environment variables
  container_environment = {
    ENV = "production"
    LOG_LEVEL = "info"
  }

  # Optional: Secrets from AWS Secrets Manager
  container_secrets = {
    DB_PASSWORD = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password"
  }

  # Optional: SNS notifications
  sns_topic_arn = aws_sns_topic.deployments.arn

  tags = {
    Project = "MyApp"
    Team    = "DevOps"
  }
}
```

### Module Inputs

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `environment` | Environment name | string | - | Yes |
| `app_name` | Application name | string | - | Yes |
| `vpc_id` | VPC ID | string | - | Yes |
| `subnet_ids` | Subnet IDs for tasks/ALB | list(string) | - | Yes |
| `certificate_arn` | ACM certificate ARN | string | - | Yes |
| `container_image` | Docker image | string | - | Yes |
| `container_port` | Container port | number | 80 | No |
| `cpu` | Fargate CPU units | number | 256 | No |
| `memory` | Fargate memory (MB) | number | 512 | No |
| `desired_count` | Number of tasks | number | 2 | No |
| `health_check_path` | Health check endpoint | string | "/" | No |
| `deployment_timeout_minutes` | Deployment timeout | number | 10 | No |
| `enable_auto_rollback` | Auto rollback on failure | bool | true | No |

### Module Outputs

```hcl
# Access deployed resources
output "alb_dns_name" {
  value = module.blue_green_deployment.alb_dns_name
}

output "cluster_name" {
  value = module.blue_green_deployment.cluster_name
}

output "codedeploy_app_name" {
  value = module.blue_green_deployment.codedeploy_app_name
}
```

## Deployment Scripts

### deploy.sh - Trigger Deployment

**Purpose:** Deploy a new container image using blue-green deployment.

```bash
./scripts/blue-green/deploy.sh \
  --environment prod \
  --app-name webapp \
  --image myapp:v2.0 \
  --region us-east-1 \
  --wait
```

**Options:**
- `-e, --environment`: Environment name (required)
- `-a, --app-name`: Application name (required)
- `-i, --image`: Docker image URI (required)
- `-r, --region`: AWS region (default: us-east-1)
- `-w, --wait`: Wait for deployment completion
- `-n, --no-wait`: Don't wait (default)

**What it does:**
1. Retrieves current task definition
2. Creates new task definition with new image
3. Generates AppSpec file
4. Triggers CodeDeploy deployment
5. Optionally waits for completion

### rollback.sh - Rollback Deployment

**Purpose:** Stop current deployment and rollback to previous version.

```bash
./scripts/blue-green/rollback.sh \
  --environment prod \
  --app-name webapp
```

**Options:**
- `-e, --environment`: Environment name (required)
- `-a, --app-name`: Application name (required)
- `-d, --deployment-id`: Specific deployment ID (optional)
- `-r, --region`: AWS region (default: us-east-1)
- `-s, --stop-only`: Only stop, don't rollback

**What it does:**
1. Finds current or specified deployment
2. Stops the deployment
3. Triggers automatic rollback (unless --stop-only)
4. Deploys previous successful version

### status.sh - Monitor Deployments

**Purpose:** Check deployment status and health.

```bash
./scripts/blue-green/status.sh \
  --environment prod \
  --app-name webapp \
  --watch
```

**Options:**
- `-e, --environment`: Environment name (required)
- `-a, --app-name`: Application name (required)
- `-d, --deployment-id`: Specific deployment ID (optional)
- `-r, --region`: AWS region (default: us-east-1)
- `-w, --watch`: Continuous monitoring (refreshes every 10s)

**Displays:**
- ECS service status (running/desired/pending tasks)
- Target group health (blue and green)
- Recent deployments
- Active deployment progress

## Usage Examples

### Example 1: Basic Deployment

```bash
# Deploy new version
./scripts/blue-green/deploy.sh -e prod -a api -i myapi:v1.5.0

# Check status
./scripts/blue-green/status.sh -e prod -a api
```

### Example 2: Deployment with Waiting

```bash
# Deploy and wait for completion
./scripts/blue-green/deploy.sh \
  -e staging \
  -a webapp \
  -i webapp:latest \
  --wait
```

### Example 3: Test Before Production

```bash
# Deploy to staging first
./scripts/blue-green/deploy.sh -e staging -a webapp -i webapp:v2.0 -w

# Run tests
curl https://staging-webapp-alb-xxx.us-east-1.elb.amazonaws.com/health

# Deploy to production
./scripts/blue-green/deploy.sh -e prod -a webapp -i webapp:v2.0 -w
```

### Example 4: Emergency Rollback

```bash
# Quick rollback
./scripts/blue-green/rollback.sh -e prod -a webapp

# Check status
./scripts/blue-green/status.sh -e prod -a webapp
```

### Example 5: CI/CD Integration

```yaml
# GitHub Actions example
name: Deploy to ECS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Build and push image
        run: |
          docker build -t myapp:${{ github.sha }} .
          docker tag myapp:${{ github.sha }} $ECR_REGISTRY/myapp:${{ github.sha }}
          docker push $ECR_REGISTRY/myapp:${{ github.sha }}

      - name: Deploy to ECS
        run: |
          ./scripts/blue-green/deploy.sh \
            -e prod \
            -a webapp \
            -i $ECR_REGISTRY/myapp:${{ github.sha }} \
            --wait
```

## Advanced Topics

### Custom Deployment Configurations

CodeDeploy supports different traffic shifting strategies:

1. **All-at-Once** (Default)
   - Shifts 100% traffic immediately
   - Fastest deployment

2. **Canary**
   - Shifts X% first, then 100% after wait time
   - Example: 10% then 90%

3. **Linear**
   - Gradual traffic shift
   - Example: 10% every minute

To customize, update the deployment configuration in Terraform:

```hcl
resource "aws_codedeploy_deployment_config" "custom" {
  deployment_config_name = "Custom10PercentEveryMinute"
  compute_platform       = "ECS"

  traffic_routing_config {
    type = "TimeBasedLinear"

    time_based_linear {
      interval   = 1
      percentage = 10
    }
  }
}

# Reference in deployment group
deployment_config_name = aws_codedeploy_deployment_config.custom.id
```

### CloudWatch Alarms Integration

Trigger automatic rollback on metrics:

```hcl
resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${var.environment}-${var.app_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "High error rate"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# Add to deployment group
alarm_configuration {
  enabled = true
  alarms  = [aws_cloudwatch_metric_alarm.errors.alarm_name]
}
```

### Testing New Version

Test the green environment before production traffic:

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test via test listener (port 8443)
curl -k https://${ALB_DNS}:8443/health

# Run comprehensive tests
./tests/integration-tests.sh --endpoint https://${ALB_DNS}:8443
```

### Custom AppSpec Hooks

Add lifecycle hooks for custom logic:

```json
{
  "version": 0.0,
  "Resources": [{
    "TargetService": {
      "Type": "AWS::ECS::Service",
      "Properties": {
        "TaskDefinition": "arn:aws:ecs:...",
        "LoadBalancerInfo": {
          "ContainerName": "webapp",
          "ContainerPort": 80
        }
      }
    }
  }],
  "Hooks": [
    {
      "BeforeInstall": "BeforeInstallHookFunctionName"
    },
    {
      "AfterInstall": "AfterInstallHookFunctionName"
    },
    {
      "AfterAllowTestTraffic": "AfterTestTrafficHookFunctionName"
    },
    {
      "BeforeAllowTraffic": "BeforeAllowTrafficHookFunctionName"
    },
    {
      "AfterAllowTraffic": "AfterAllowTrafficHookFunctionName"
    }
  ]
}
```

## Troubleshooting

### Common Issues

#### 1. Deployment Stuck in "InProgress"

**Symptoms:** Deployment doesn't progress past "InProgress" status.

**Causes:**
- Health checks failing
- Tasks not starting
- Security group misconfiguration

**Solution:**
```bash
# Check ECS service events
aws ecs describe-services \
  --cluster prod-webapp-cluster \
  --services prod-webapp-service \
  --query 'services[0].events[0:10]'

# Check task logs
aws logs tail /ecs/prod/webapp --follow

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <green-tg-arn>
```

#### 2. Health Checks Failing

**Symptoms:** Targets never become healthy.

**Solution:**
- Verify health check path returns 200
- Check security group allows ALB → ECS communication
- Increase `startPeriod` in task definition
- Verify container is actually listening on the port

```bash
# Test health check from within container
aws ecs execute-command \
  --cluster prod-webapp-cluster \
  --task <task-id> \
  --container webapp \
  --interactive \
  --command "curl localhost/health"
```

#### 3. Automatic Rollback Triggered

**Symptoms:** Deployment rolls back automatically.

**Causes:**
- CloudWatch alarms triggered
- Deployment timeout exceeded
- Health checks failing

**Solution:**
```bash
# Check deployment details
aws deploy get-deployment \
  --deployment-id d-XXXXX \
  --query 'deploymentInfo.errorInformation'

# Check CloudWatch alarms
aws cloudwatch describe-alarm-history \
  --alarm-name prod-webapp-errors \
  --max-records 10
```

#### 4. Tasks Can't Pull Image

**Symptoms:** Tasks fail to start with "CannotPullContainerError".

**Solution:**
- Verify ECR permissions in task execution role
- Check image exists and tag is correct
- Ensure NAT Gateway for private subnets

```bash
# Test ECR access
aws ecr describe-images \
  --repository-name myapp \
  --image-ids imageTag=v1.0
```

### Debug Commands

```bash
# View deployment details
aws deploy get-deployment --deployment-id d-XXXXX

# List recent deployments
aws deploy list-deployments \
  --application-name prod-webapp \
  --max-items 10

# Check ECS task status
aws ecs list-tasks --cluster prod-webapp-cluster
aws ecs describe-tasks --cluster prod-webapp-cluster --tasks <task-arn>

# View container logs
aws logs tail /ecs/prod/webapp --follow --since 10m

# Check target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# View CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HealthyHostCount \
  --dimensions Name=TargetGroup,Value=targetgroup/prod-webapp-blue-tg/xxxxx \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average
```

## Best Practices

### 1. Testing Strategy

- **Test in staging first** - Always deploy to staging before production
- **Automated tests** - Run integration tests on green environment
- **Gradual rollout** - Use canary or linear traffic shifting for large changes
- **Monitoring** - Watch metrics closely during deployment

### 2. Rollback Strategy

- **Keep previous versions** - Don't delete old task definitions
- **Fast rollback** - Practice rollback procedures
- **Automated rollback** - Enable auto-rollback on alarms
- **Document reasons** - Log why rollbacks occurred

### 3. Security

- **Least privilege IAM** - Minimal permissions for each role
- **Secrets management** - Use AWS Secrets Manager, not environment variables
- **HTTPS only** - Force HTTPS, redirect HTTP
- **Security groups** - Restrict access to necessary sources only
- **Regular updates** - Keep base images and dependencies updated

### 4. Monitoring

- **CloudWatch Logs** - Centralized logging for all tasks
- **Metrics** - Track CPU, memory, request count, latency, errors
- **Alarms** - Alert on anomalies
- **Dashboards** - Visualize deployment progress and health

### 5. Cost Optimization

- **Right-size tasks** - Don't over-provision CPU/memory
- **Fargate Spot** - Use Spot for dev/staging
- **Log retention** - Set appropriate CloudWatch log retention
- **Clean old resources** - Remove old task definitions

### 6. Deployment Guidelines

- **Off-peak hours** - Deploy during low traffic for production
- **Gradual rollout** - Use canary deployments for risky changes
- **Feature flags** - Enable gradual feature rollout
- **Database migrations** - Plan carefully, consider blue-green for databases too
- **Communication** - Notify team before/after deployments

## Additional Resources

- [AWS CodeDeploy Documentation](https://docs.aws.amazon.com/codedeploy/)
- [ECS Blue/Green Deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Blue-Green Deployment Best Practices](https://martinfowler.com/bliki/BlueGreenDeployment.html)

---

**Need help?** Open an issue or check the troubleshooting guide above.

**Made with ❤️ for zero-downtime deployments!**

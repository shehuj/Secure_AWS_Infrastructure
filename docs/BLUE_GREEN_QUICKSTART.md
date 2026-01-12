# Blue-Green Deployment - Quick Start Guide

Get up and running with zero-downtime deployments in 10 minutes!

## 🚀 Quick Start (5 Steps)

### Step 1: Prepare Your Variables

```bash
cd terraform

cat > blue-green.tfvars <<EOF
# Required variables
environment     = "prod"
app_name        = "webapp"
vpc_id          = "vpc-xxxxx"        # Your VPC ID
subnet_ids      = ["subnet-xxxxx", "subnet-yyyyy"]  # Public subnets
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"

# Container configuration
container_image = "nginx:latest"
container_port  = 80
cpu             = 256
memory          = 512
desired_count   = 2
EOF
```

### Step 2: Deploy Infrastructure

```bash
# Create a main.tf that uses the module
cat > main-bluegreen.tf <<'EOF'
module "webapp_bluegreen" {
  source = "./modules/ecs_bluegreen"

  environment     = var.environment
  app_name        = var.app_name
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids
  certificate_arn = var.certificate_arn

  container_image = var.container_image
  container_port  = var.container_port
  cpu             = var.cpu
  memory          = var.memory
  desired_count   = var.desired_count

  trusted_ip_ranges = ["0.0.0.0/0"]  # Restrict in production!

  health_check_path    = "/"
  health_check_matcher = "200"

  enable_auto_rollback = true
  log_retention_days   = 7

  tags = {
    ManagedBy = "Terraform"
  }
}

output "alb_dns" {
  value = module.webapp_bluegreen.alb_dns_name
}
EOF

# Deploy!
terraform init
terraform plan -var-file=blue-green.tfvars
terraform apply -var-file=blue-green.tfvars
```

⏱️ **This takes ~5 minutes**

### Step 3: Test Your Infrastructure

```bash
# Get the ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns)

# Test HTTPS endpoint
curl -k https://$ALB_DNS/

# You should see the default nginx page!
```

### Step 4: Deploy a New Version

```bash
# Make scripts executable
chmod +x scripts/blue-green/*.sh

# Deploy nginx 1.21
./scripts/blue-green/deploy.sh \
  -e prod \
  -a webapp \
  -i nginx:1.21 \
  --wait
```

⏱️ **This takes ~3-5 minutes**

You'll see:
```
[INFO] ==========================================
[INFO] Blue-Green Deployment
[INFO] ==========================================
[INFO] Environment: prod
[INFO] Application: webapp
[INFO] Image: nginx:1.21
[INFO] Region: us-east-1

[SUCCESS] Cluster found: prod-webapp-cluster
[INFO] Retrieving current task definition...
[INFO] Creating new task definition with image: nginx:1.21
[SUCCESS] New task definition registered...
[SUCCESS] Deployment triggered successfully!
[INFO] Deployment ID: d-XXXXX
[INFO] Waiting for deployment to complete...
[SUCCESS] Deployment completed successfully!
```

### Step 5: Monitor and Verify

```bash
# Check status
./scripts/blue-green/status.sh -e prod -a webapp

# Watch in real-time
./scripts/blue-green/status.sh -e prod -a webapp --watch
```

## 🎯 Using the Makefile (Even Easier!)

```bash
cd scripts/blue-green

# Deploy new version
make deploy APP=webapp IMAGE=nginx:1.21 ENV=prod

# Deploy and wait
make deploy-wait APP=webapp IMAGE=nginx:1.22 ENV=prod

# Check status
make status APP=webapp ENV=prod

# Watch deployment
make watch APP=webapp ENV=prod

# Rollback if needed
make rollback APP=webapp ENV=prod
```

## 🔄 Common Workflows

### Workflow 1: Deploy to Staging, Then Production

```bash
# Deploy to staging
./scripts/blue-green/deploy.sh -e staging -a webapp -i webapp:v2.0 -w

# Test staging
curl https://staging-alb-xxx.elb.amazonaws.com/health

# Deploy to production
./scripts/blue-green/deploy.sh -e prod -a webapp -i webapp:v2.0 -w
```

### Workflow 2: Gradual Rollout

```bash
# Deploy to 10% of traffic (canary)
# (Requires custom deployment config - see advanced docs)

# Monitor for 10 minutes
./scripts/blue-green/status.sh -e prod -a webapp --watch

# If everything looks good, shift 100% traffic
# (Automatic after wait time)
```

### Workflow 3: Emergency Rollback

```bash
# Something wrong? Roll back immediately!
./scripts/blue-green/rollback.sh -e prod -a webapp

# Check that rollback succeeded
./scripts/blue-green/status.sh -e prod -a webapp
```

## 📊 What You Get

After deployment, you have:

✅ **ECS Cluster** - Running Fargate tasks
✅ **Application Load Balancer** - With blue and green target groups
✅ **HTTPS Endpoint** - SSL/TLS encrypted traffic
✅ **Test Endpoint** - Port 8443 for testing green deployments
✅ **CodeDeploy** - Orchestrating blue-green deployments
✅ **CloudWatch Logs** - Centralized logging
✅ **Auto Rollback** - Automatic rollback on failure
✅ **Zero Downtime** - No service interruption during deployments

## 🔍 Verify Everything Works

### 1. Check ECS Service

```bash
aws ecs describe-services \
  --cluster prod-webapp-cluster \
  --services prod-webapp-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
```

Expected: `Running: 2, Desired: 2`

### 2. Check Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names prod-webapp-blue-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
```

Expected: All targets `healthy`

### 3. Test HTTPS Endpoint

```bash
ALB_DNS=$(terraform output -raw alb_dns)
curl -k https://$ALB_DNS/
```

Expected: HTTP 200 OK with content

### 4. View Logs

```bash
aws logs tail /ecs/prod/webapp --follow
```

Expected: Application logs streaming

## 🛠️ Customize Your Deployment

### Add Environment Variables

```hcl
# In your terraform config
container_environment = {
  NODE_ENV  = "production"
  LOG_LEVEL = "info"
  DATABASE_URL = "postgres://..."
}
```

### Add Secrets

```hcl
container_secrets = {
  DB_PASSWORD = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password"
  API_KEY     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:api-key"
}
```

### Change Resource Allocation

```hcl
cpu           = 1024  # 1 vCPU
memory        = 2048  # 2 GB
desired_count = 4     # 4 tasks
```

### Enable Notifications

```hcl
# Create SNS topic first
resource "aws_sns_topic" "deployments" {
  name = "deployment-notifications"
}

# Add to module
sns_topic_arn = aws_sns_topic.deployments.arn
```

## 🚨 Troubleshooting

### Issue: Tasks Not Starting

```bash
# Check task events
aws ecs describe-services \
  --cluster prod-webapp-cluster \
  --services prod-webapp-service \
  --query 'services[0].events[0:5]'

# Common causes:
# - Can't pull image (check ECR permissions)
# - Can't create network interface (check security groups)
# - Can't write logs (check task execution role)
```

### Issue: Health Checks Failing

```bash
# Check target health details
aws elbv2 describe-target-health \
  --target-group-arn <your-tg-arn> \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth}'

# Common causes:
# - Wrong health check path
# - Container not listening on correct port
# - Security group blocking traffic from ALB
```

### Issue: Deployment Stuck

```bash
# Check deployment status
aws deploy get-deployment \
  --deployment-id <deployment-id> \
  --query 'deploymentInfo.{Status:status,ErrorInfo:errorInformation}'

# Check if tasks are healthy
./scripts/blue-green/status.sh -e prod -a webapp

# If needed, stop and rollback
./scripts/blue-green/rollback.sh -e prod -a webapp
```

## 📚 Next Steps

1. **Read the full documentation**: `docs/BLUE_GREEN_DEPLOYMENT.md`
2. **Set up CI/CD**: Integrate with GitHub Actions or other CI/CD tools
3. **Configure monitoring**: Add CloudWatch dashboards and alarms
4. **Customize deployment**: Use canary or linear traffic shifting
5. **Add Route53**: Point your domain to the ALB

## 🎓 Learn More

- [Full Documentation](./BLUE_GREEN_DEPLOYMENT.md)
- [Terraform Module Details](../terraform/modules/ecs_bluegreen/)
- [Example Configuration](../terraform/examples/blue-green-deployment.tf)
- [Deployment Scripts](../scripts/blue-green/)

## ✅ Checklist

- [ ] Infrastructure deployed with Terraform
- [ ] Can access ALB HTTPS endpoint
- [ ] First deployment successful
- [ ] Monitoring scripts work
- [ ] Tested rollback procedure
- [ ] Set up SNS notifications (optional)
- [ ] Configured CloudWatch alarms (optional)
- [ ] Added Route53 DNS record (optional)
- [ ] Integrated with CI/CD (optional)

---

**Ready to deploy?** You now have a production-ready blue-green deployment setup! 🚀

**Need help?** Check the [full documentation](./BLUE_GREEN_DEPLOYMENT.md) or open an issue.

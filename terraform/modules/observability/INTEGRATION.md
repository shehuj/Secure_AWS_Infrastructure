# Integration Guide

This guide shows how to integrate the observability module into your existing Terraform configuration.

## Step 1: Add Variables

Add these variables to your root `variables.tf`:

```hcl
variable "grafana_domain_name" {
  description = "Domain name for Grafana (e.g., grafana.example.com)"
  type        = string
}

variable "grafana_certificate_arn" {
  description = "ARN of the ACM certificate for Grafana HTTPS"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "changeme123"  # Change in production!
}

variable "enable_observability" {
  description = "Enable Prometheus and Grafana monitoring stack"
  type        = bool
  default     = false
}
```

## Step 2: Add to terraform.tfvars

```hcl
grafana_domain_name      = "grafana.claudiq.com"
grafana_certificate_arn  = "arn:aws:acm:us-east-1:YOUR_ACCOUNT:certificate/YOUR_CERT_ID"
grafana_admin_password   = "YourSecurePassword123!"
enable_observability     = true
```

## Step 3: Add Module to main.tf

Add this module declaration after your existing modules:

```hcl
# Observability Module (Prometheus + Grafana)
module "observability" {
  count  = var.enable_observability ? 1 : 0
  source = "./modules/observability"

  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.public_subnet_ids
  environment      = var.environment
  ecs_cluster_id   = module.ghost_blog.ecs_cluster_arn
  ecs_cluster_name = module.ghost_blog.ecs_cluster_name
  certificate_arn  = var.grafana_certificate_arn
  grafana_domain   = var.grafana_domain_name

  ghost_service_name     = module.ghost_blog.ecs_service_name
  grafana_admin_password = var.grafana_admin_password

  prometheus_retention_days = 15

  cloudwatch_metrics_namespaces = [
    "AWS/EC2",
    "AWS/ECS",
    "AWS/ApplicationELB",
    "AWS/EFS"
  ]

  tags = var.tags

  depends_on = [module.ghost_blog]
}
```

## Step 4: Add Outputs

Add these outputs to your root `outputs.tf`:

```hcl
# Observability Outputs
output "grafana_url" {
  description = "URL to access Grafana"
  value       = var.enable_observability ? module.observability[0].grafana_url : null
}

output "grafana_alb_dns_name" {
  description = "DNS name of the Grafana ALB"
  value       = var.enable_observability ? module.observability[0].grafana_alb_dns_name : null
}

output "grafana_alb_zone_id" {
  description = "Canonical hosted zone ID of the Grafana ALB"
  value       = var.enable_observability ? module.observability[0].grafana_alb_zone_id : null
}

output "prometheus_endpoint" {
  description = "Internal endpoint for Prometheus"
  value       = var.enable_observability ? module.observability[0].prometheus_endpoint : null
}
```

## Step 5: Create ACM Certificate (if needed)

If you don't have a certificate for your Grafana domain:

```bash
# Request certificate
aws acm request-certificate \
  --domain-name grafana.claudiq.com \
  --validation-method DNS \
  --region us-east-1

# Get certificate ARN
aws acm list-certificates --region us-east-1

# Validate using DNS (add the CNAME record shown in the output to Route 53)
```

## Step 6: Apply Configuration

```bash
cd terraform

# Initialize new module
terraform init

# Plan changes
terraform plan -var="enable_observability=true"

# Apply
terraform apply -var="enable_observability=true"
```

## Step 7: Configure DNS for Grafana

After deployment, create a Route 53 A record:

```bash
# Get outputs
ALB_DNS=$(terraform output -raw grafana_alb_dns_name)
ALB_ZONE=$(terraform output -raw grafana_alb_zone_id)

# Create DNS record
aws route53 change-resource-record-sets \
  --hosted-zone-id Z04492601HFUDC7HTYJ6B \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "grafana.claudiq.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'$ALB_ZONE'",
          "DNSName": "'$ALB_DNS'",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'
```

## Step 8: Access Grafana

1. Wait 2-3 minutes for ECS tasks to start
2. Navigate to `https://grafana.claudiq.com`
3. Login with:
   - Username: `admin`
   - Password: `<your grafana_admin_password>`

## Step 9: Add Prometheus Datasource in Grafana

1. Click **Configuration** (gear icon) → **Data Sources**
2. Click **Add data source**
3. Select **Prometheus**
4. Configure:
   - Name: `Prometheus`
   - URL: `http://prometheus.prod.local:9090`
   - Access: `Server (default)`
5. Click **Save & Test**

## Step 10: Import Dashboards

1. Click **+** → **Import**
2. Import these dashboard IDs:
   - **12049** - AWS ECS Fargate
   - **3662** - Prometheus 2.0 Overview
   - **1860** - Node Exporter Full (if you add node exporters)

## Troubleshooting

### Can't access Grafana URL
- Check DNS propagation: `dig grafana.claudiq.com`
- Verify certificate matches domain
- Check security groups allow ports 80/443

### Prometheus not discovering targets
- Check ECS service discovery: `aws servicediscovery list-services`
- Verify IAM permissions for Prometheus task role
- Check Prometheus logs: `aws logs tail /ecs/prod/prometheus --follow`

### Grafana can't connect to Prometheus
- Test DNS: `nslookup prometheus.prod.local` from Grafana task
- Check security groups allow port 9090
- Verify Prometheus service is running

## Advanced Configuration

### Add CloudWatch Exporter

To scrape CloudWatch metrics, add this container to the Prometheus task definition:

```hcl
{
  name  = "cloudwatch-exporter"
  image = "prom/cloudwatch-exporter:latest"
  portMappings = [{
    containerPort = 9106
    protocol      = "tcp"
  }]
}
```

### Add Alert Manager

Deploy Alertmanager for alert routing:

```hcl
module "alertmanager" {
  source = "./modules/alertmanager"
  # ... configuration
}
```

### Remote Storage

For long-term metrics storage, consider:
- Amazon Managed Service for Prometheus (AMP)
- Cortex
- Thanos
- VictoriaMetrics

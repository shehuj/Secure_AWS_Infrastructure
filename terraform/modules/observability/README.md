# Observability Module - Prometheus & Grafana

This module deploys a complete observability stack with Prometheus and Grafana on ECS Fargate.

## Features

- **Prometheus** for metrics collection and storage
- **Grafana** for visualization and dashboards
- **ECS Service Discovery** for automatic target discovery
- **EFS** for persistent storage
- **ALB** for secure HTTPS access to Grafana
- **CloudWatch integration** via CloudWatch Exporter

## Architecture

```
Internet -> ALB (HTTPS) -> Grafana (ECS Fargate) -> Prometheus (ECS Fargate)
                                |                         |
                               EFS                       EFS
                             (Data)                  (Metrics)
```

## Usage

### 1. Add Module to Your Configuration

```hcl
module "observability" {
  source = "./modules/observability"

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.public_subnet_ids
  environment         = var.environment
  ecs_cluster_id      = module.ghost_blog.ecs_cluster_id
  ecs_cluster_name    = module.ghost_blog.ecs_cluster_name
  certificate_arn     = var.grafana_certificate_arn
  grafana_domain      = "grafana.example.com"
  ghost_service_name  = module.ghost_blog.ecs_service_name

  grafana_admin_password = "YourSecurePassword123!"  # Use AWS Secrets Manager in production

  tags = var.tags
}
```

### 2. Configure DNS

Create a Route 53 A record (Alias) pointing to the Grafana ALB:

```bash
aws route53 change-resource-record-sets --hosted-zone-id YOUR_ZONE_ID --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "grafana.example.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "<GRAFANA_ALB_ZONE_ID>",
        "DNSName": "<GRAFANA_ALB_DNS_NAME>",
        "EvaluateTargetHealth": true
      }
    }
  }]
}'
```

### 3. Upload Prometheus Configuration

After deployment, you need to upload the Prometheus configuration to EFS:

```bash
# Get the Prometheus config from SSM
aws ssm get-parameter --name "/prod/prometheus/config" --query "Parameter.Value" --output text > prometheus.yml

# Mount EFS and upload config (requires EC2 instance or ECS task with EFS mount)
# Or use an init container in the Prometheus task definition
```

### 4. Access Grafana

1. Navigate to `https://grafana.example.com`
2. Login with:
   - Username: `admin`
   - Password: `<value from grafana_admin_password variable>`

3. Add Prometheus datasource:
   - URL: `http://prometheus.prod.local:9090`
   - Access: Server (default)

## Metrics Sources

### ECS Tasks
- CPU utilization
- Memory utilization
- Network I/O
- Task count

### Ghost Application
The module is configured to scrape metrics from Ghost if it exposes a `/metrics` endpoint.

To add metrics to Ghost, you can use the `prom-client` npm package.

### CloudWatch Metrics
To scrape AWS CloudWatch metrics, add the CloudWatch Exporter as a sidecar container.

## Default Dashboards

Import these Grafana dashboard IDs:
- **1860** - Node Exporter Full
- **12049** - AWS ECS Fargate
- **11074** - Prometheus Stats

## Storage

- **Prometheus**: EFS with 15 days retention (configurable)
- **Grafana**: EFS for dashboards and configurations

## Security

- HTTPS enforced on ALB
- Security groups restrict traffic between components
- EFS encrypted at rest and in transit
- Task roles follow least privilege principle

## Monitoring the Monitoring

Prometheus monitors itself and Grafana also has built-in metrics.

## Costs

Approximate monthly costs (us-east-1):
- ECS Fargate (2 tasks @ 0.5 vCPU, 1 GB): ~$15
- ALB: ~$20
- EFS (assuming 10 GB): ~$3
- Data transfer: ~$5
- **Total**: ~$43/month

## Troubleshooting

### Prometheus not scraping targets
1. Check security groups allow traffic on required ports
2. Verify ECS service discovery is working
3. Check Prometheus logs: `aws logs tail /ecs/prod/prometheus --follow`

### Grafana not connecting to Prometheus
1. Verify Prometheus service discovery DNS: `prometheus.prod.local`
2. Check security groups allow port 9090
3. Test connectivity from Grafana task

### EFS mount issues
1. Ensure EFS mount targets exist in all subnets
2. Check security groups allow NFS (port 2049)
3. Verify ECS task execution role has EFS permissions

## Scaling

To handle more metrics:
1. Increase Prometheus task CPU/memory
2. Adjust `prometheus_retention_days` (default: 15 days)
3. Consider adding remote storage (e.g., Cortex, Thanos)

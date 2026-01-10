# Observability Module - Prometheus & Grafana

This module deploys a complete observability stack with Prometheus and Grafana on ECS Fargate.

## Quick Access

**Grafana URL**: `https://grafana.example.com` (replace with your configured domain)

**Default Login**:
- Username: `admin`
- Password: Set in `grafana_admin_password` variable

**Prometheus Internal Endpoint**: `http://prometheus.prod.local:9090`

---

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

### 3. Verify Services are Running

Wait 2-3 minutes after deployment, then check that both services are running:

```bash
aws ecs describe-services \
  --cluster <your-cluster-name> \
  --services prod-prometheus-service prod-grafana-service \
  --query 'services[*].{Name:serviceName,Desired:desiredCount,Running:runningCount}' \
  --output table
```

You should see both services with `Running: 1`.

### 4. Access Grafana

Navigate to your Grafana URL: `https://grafana.example.com` (replace with your domain)

**Login Credentials**:
- **Username**: `admin`
- **Password**: `<value from grafana_admin_password variable>`

### 5. Initial Setup (5 minutes)

After logging in for the first time, follow these steps to get your monitoring up and running:

#### Step 1: Add Prometheus Data Source

1. Click the **gear icon** ⚙️ (Configuration) on the left sidebar
2. Click **Data Sources**
3. Click **Add data source**
4. Select **Prometheus**
5. Configure:
   - **Name**: `Prometheus`
   - **URL**: `http://prometheus.prod.local:9090`
   - **Access**: `Server (default)`
   - Leave all other settings as default
6. Click **Save & Test** (you should see a green ✅ checkmark)

#### Step 2: Import Pre-built Dashboards

Click **+** icon on the left sidebar → **Import dashboard**

Import these dashboards one by one:

| Dashboard ID | Name | Description |
|--------------|------|-------------|
| **12049** | AWS ECS Fargate | Container CPU, memory, network I/O, task count |
| **3662** | Prometheus 2.0 Overview | Prometheus performance and scrape metrics |
| **1860** | Node Exporter Full | System metrics (if you add node exporters) |

**How to import**:
1. Enter the dashboard ID (e.g., `12049`)
2. Click **Load**
3. Select **Prometheus** as the data source
4. Click **Import**

#### Step 3: View Your Metrics

After importing the dashboards, you'll see:
- ✅ Ghost container CPU and memory usage
- ✅ ECS task count and health
- ✅ Network I/O metrics
- ✅ ALB request/response metrics
- ✅ Prometheus scrape performance

#### Step 4: Customize (Optional)

**Change Time Range**: Top right corner - change from "Last 6 hours" to "Last 24 hours"

**Set Auto-Refresh**: Top right corner - set to 30s or 1m for live monitoring

**Create Custom Dashboard**:
1. Click **+** → **Dashboard** → **Add visualization**
2. Select **Prometheus** data source
3. Use these example queries:

```promql
# Ghost ECS CPU Usage
aws_ecs_service_cpu_utilization_average{service_name="prod-ghost-service"}

# Ghost ECS Memory Usage
aws_ecs_service_memory_utilization_average{service_name="prod-ghost-service"}

# Ghost Task Count
aws_ecs_service_desired_tasks{service_name="prod-ghost-service"}

# ALB Request Count
aws_application_elb_request_count_sum{load_balancer="app/prod-ghost-alb"}

# ALB Response Time
aws_application_elb_target_response_time_average{load_balancer="app/prod-ghost-alb"}
```

#### Step 5: Change Default Password (Recommended)

For security, change the default admin password:
1. Click your **profile icon** (bottom left)
2. Go to **Preferences**
3. Click **Change Password**
4. Enter current password and new password
5. Click **Save**

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

## Recommended Dashboards

Import these Grafana dashboard IDs (see Step 2 in Initial Setup above):
- **12049** - AWS ECS Fargate (Container metrics, task count, network I/O)
- **3662** - Prometheus 2.0 Overview (Prometheus performance metrics)
- **1860** - Node Exporter Full (System metrics - requires node exporters)

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

### Services not starting

Check ECS service status:
```bash
aws ecs describe-services \
  --cluster prod-ghost-cluster \
  --services prod-prometheus-service prod-grafana-service \
  --query 'services[*].{Name:serviceName,Desired:desiredCount,Running:runningCount,Events:events[0].message}' \
  --output table
```

If `Running: 0`:
1. Check CloudWatch logs: `aws logs tail /ecs/prod/prometheus --follow`
2. Look for EFS mount errors or configuration issues
3. Verify security groups allow necessary ports

### Can't access Grafana URL

1. **Check DNS resolution**: `dig grafana.claudiq.com +short`
   - Should return ALB IP addresses
   - If not, verify Route 53 A record is configured

2. **Verify ALB is running**:
   ```bash
   terraform output grafana_alb_dns_name
   # Test direct access
   curl -I https://<ALB-DNS-NAME>/
   ```

3. **Check certificate**: Ensure ACM certificate covers your domain
   ```bash
   terraform output grafana_certificate_arn
   ```

### Prometheus not scraping targets
1. Check security groups allow traffic on required ports
2. Verify ECS service discovery is working
3. Check Prometheus logs: `aws logs tail /ecs/prod/prometheus --follow`
4. Verify Prometheus config in SSM: `aws ssm get-parameter --name /prod/prometheus/config`

### Grafana not connecting to Prometheus
1. In Grafana, verify data source URL: `http://prometheus.prod.local:9090`
2. Check security groups allow port 9090 between tasks
3. Test Prometheus endpoint:
   ```bash
   # From within Grafana task or same VPC
   curl http://prometheus.prod.local:9090/api/v1/status/config
   ```

### No metrics showing in dashboards
1. Wait 5-10 minutes after deployment for metrics to populate
2. Check Prometheus targets: In Grafana → Explore → `up` query
3. Verify time range in dashboard (top right) covers recent data
4. Check if Prometheus is successfully scraping:
   - Go to Prometheus directly (if accessible)
   - Or check logs: `aws logs tail /ecs/prod/prometheus --since 10m`

### EFS mount issues
1. Ensure EFS mount targets exist in all subnets
2. Check security groups allow NFS (port 2049)
3. Verify ECS task execution role has EFS permissions
4. Check EFS mount target status:
   ```bash
   aws efs describe-mount-targets --file-system-id <EFS-ID>
   ```

## Scaling

To handle more metrics:
1. Increase Prometheus task CPU/memory
2. Adjust `prometheus_retention_days` (default: 15 days)
3. Consider adding remote storage (e.g., Cortex, Thanos)

## Useful Commands

### Check service health
```bash
# View all monitoring services
aws ecs list-services --cluster prod-ghost-cluster | grep -E "(prometheus|grafana)"

# Check task count
aws ecs describe-services \
  --cluster prod-ghost-cluster \
  --services prod-prometheus-service prod-grafana-service \
  --query 'services[*].{Name:serviceName,Running:runningCount,Desired:desiredCount}'
```

### View logs
```bash
# Grafana logs
aws logs tail /ecs/prod/grafana --follow

# Prometheus logs
aws logs tail /ecs/prod/prometheus --follow

# Recent errors only
aws logs tail /ecs/prod/prometheus --since 1h --filter-pattern "ERROR"
```

### Get outputs
```bash
# Get Grafana URL
terraform output grafana_url

# Get ALB DNS
terraform output grafana_alb_dns_name

# Get Prometheus internal endpoint
terraform output prometheus_endpoint
```

### Restart services
```bash
# Force new deployment (restarts tasks)
aws ecs update-service \
  --cluster prod-ghost-cluster \
  --service prod-grafana-service \
  --force-new-deployment

aws ecs update-service \
  --cluster prod-ghost-cluster \
  --service prod-prometheus-service \
  --force-new-deployment
```

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [PromQL Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

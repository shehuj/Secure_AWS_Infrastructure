# Route 53 Configuration
route53_zone_id = "Z04492601HFUDC7HTYJ6B" # claudiq.com hosted zone

# ACM Certificate (used for ALB HTTPS listeners)
acm_certificate_arn = "arn:aws:acm:us-east-1:615299732970:certificate/6025f24f-a812-41d9-b97a-cce0f4d4426b"

# EC2 root volume size - must be >= 30GB to satisfy AMI snapshot requirement
root_volume_size = 30

# Observability Configuration
# SECURITY: All sensitive values must be passed via environment variables or AWS Secrets Manager
# DO NOT commit secrets to this file

enable_observability      = true
grafana_domain_name       = "grafana.claudiq.com"

# IMPORTANT: Set these via environment variables or GitHub Secrets:
# - TF_VAR_grafana_admin_password

grafana_certificate_arn = "arn:aws:acm:us-east-1:615299732970:certificate/6025f24f-a812-41d9-b97a-cce0f4d4426b"

# grafana_admin_password will be provided via TF_VAR_grafana_admin_password or fetched from AWS Secrets Manager

prometheus_retention_days = 15
# All variables are injected via GitHub Secrets as TF_VAR_* environment variables.
# See .github/workflows/terraform-plan.yml, terraform-apply.yml, terraform-cleanup.yml.
#
# For local development, copy terraform.tfvars.example and fill in your values:
#   cp terraform.tfvars.example terraform.tfvars.local
#   terraform plan -var-file=terraform.tfvars.local

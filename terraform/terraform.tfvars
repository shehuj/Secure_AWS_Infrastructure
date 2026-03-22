# EC2 root volume size - must be >= 30GB to satisfy AMI snapshot requirement
root_volume_size = 30

# Observability
enable_observability      = true
prometheus_retention_days = 15

# Grafana admin password is stored in AWS Secrets Manager.
# Set this to the secret name (path) in Secrets Manager.
grafana_admin_password_secret_name = "/prod/grafana/admin-password"

ghost_domain_name = "claudiq.com"

# All other variables (route53_zone_id, acm_certificate_arn, grafana_certificate_arn,
# grafana_domain_name) are injected via GitHub Secrets as TF_VAR_* environment variables
# and must NOT be committed here.
# For local development, set them via environment variables or a local-only tfvars file
# that is listed in .gitignore.

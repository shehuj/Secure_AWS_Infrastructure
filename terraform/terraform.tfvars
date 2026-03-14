# All variables are injected via GitHub Secrets as TF_VAR_* environment variables.
# See .github/workflows/terraform-plan.yml, terraform-apply.yml, terraform-cleanup.yml.
#
# For local development, copy terraform.tfvars.example and fill in your values:
#   cp terraform.tfvars.example terraform.tfvars.local
#   terraform plan -var-file=terraform.tfvars.local

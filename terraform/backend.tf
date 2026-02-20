# Terraform Backend Configuration
#
# IMPORTANT: Backend values are NOT hardcoded for security/portability
#
# Setup Instructions:
# 1. Copy backend-config.hcl.example to backend-config.hcl
# 2. Update backend-config.hcl with your S3 bucket and DynamoDB table names
# 3. Run: terraform init -backend-config=backend-config.hcl
#
# Or use environment variables:
#   export TF_CLI_ARGS_init="-backend-config=bucket=YOUR-BUCKET -backend-config=dynamodb_table=YOUR-TABLE"
#   terraform init

terraform {
  backend "s3" {
    # Backend configuration is provided via:
    # - backend-config.hcl file (recommended)
    # - CLI flags: terraform init -backend-config="bucket=..." -backend-config="key=..."
    # - Environment variables: TF_CLI_ARGS_init
    bucket         = "ec2-shutdown-lambda-bucket"
    key            = "terraform.tfstate/Host"
    region         = "us-east-1"
    dynamodb_table = "dyning_table"

    # Default encryption is enabled
    encrypt = true

    # Enable state locking for idempotency
    # Prevents concurrent state modifications
  }

  # Require specific Terraform version for consistency
  required_version = ">= 1.7.0"
}

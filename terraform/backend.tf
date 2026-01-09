terraform {
  backend "s3" {
    bucket         = "your-tfstate-bucket"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true

    # Enable state locking for idempotency
    # Prevents concurrent state modifications
  }

  # Require specific Terraform version for consistency
  required_version = ">= 1.7.0"
}
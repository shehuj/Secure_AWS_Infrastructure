# create s3 bucket for Terraform for files
resource "aws_s3_bucket" "terraform_state" {
  bucket = "ec2-shutdown-lambda-bucket"

  tags = {
    Name        = "Terraform State Bucket"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
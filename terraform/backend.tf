terraform {
  backend "s3" {
    bucket         = "your-tfstate-bucket"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
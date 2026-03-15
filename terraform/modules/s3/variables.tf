variable "Action" {
  description = "Action to perform on S3 bucket (e.g. 'Create' or 'Delete')"
  type        = string
  default     = "Create"    
}

variable "environment" {
  description = "Deployment environment (e.g. 'dev', 'staging', 'prod')"
  type        = string
  default     = "dev"
}

variable "bucket_name" {
  description = "Name of the S3 bucket to create (must be globally unique)"
  type        = string
  default     = "new-bucket"
}
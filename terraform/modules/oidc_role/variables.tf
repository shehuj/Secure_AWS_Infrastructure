variable "repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
  default     = "GitHubActionsRole"
}

variable "github_repositories" {
  description = "List of GitHub repository patterns allowed to assume this role"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = ""
}

variable "terraform_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-locks"
}

variable "attach_readonly_policy" {
  description = "Whether to attach AWS ReadOnlyAccess managed policy"
  type        = bool
  default     = false
}

# terraform/modules/ecs_bluegreen/variables.tf
# Blue-Green Deployment for ECS with CodeDeploy

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks and ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS"
  type        = string
}

variable "container_image" {
  description = "Docker container image (e.g., nginx:latest)"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "Fargate CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "trusted_ip_ranges" {
  description = "List of trusted IP ranges for ALB access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "health_check_matcher" {
  description = "HTTP status codes for healthy targets"
  type        = string
  default     = "200,301"
}

variable "deployment_timeout_minutes" {
  description = "Timeout for CodeDeploy deployment in minutes"
  type        = number
  default     = 10
}

variable "termination_wait_time_minutes" {
  description = "Time to wait before terminating original task set"
  type        = number
  default     = 5
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_auto_rollback" {
  description = "Enable automatic rollback on deployment failure"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "container_environment" {
  description = "Environment variables for container"
  type        = map(string)
  default     = {}
}

variable "container_secrets" {
  description = "Secrets from AWS Secrets Manager (name -> valueFrom mapping)"
  type        = map(string)
  default     = {}
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for deployment notifications (optional)"
  type        = string
  default     = ""
}

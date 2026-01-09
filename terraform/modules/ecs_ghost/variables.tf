variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks and ALB (public subnets)"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "ghost_image" {
  description = "Docker image for Ghost (e.g., ghost:latest or ghost:5)"
  type        = string
  default     = "ghost:latest"
}

variable "ghost_domain" {
  description = "Domain name for Ghost blog (e.g., blog.example.com)"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
}

variable "desired_count" {
  description = "Desired number of Ghost tasks"
  type        = number
  default     = 2
}

variable "cpu" {
  description = "CPU units for Ghost task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory (MB) for Ghost task"
  type        = number
  default     = 1024
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

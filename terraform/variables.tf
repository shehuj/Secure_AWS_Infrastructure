# General Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# GitHub OIDC Variables
variable "github_repo" {
  description = "GitHub repository for OIDC trust (format: owner/repo)"
  type        = string
  default     = "shehuj/Secure_AWS_Infrastructure"
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

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones (leave empty for automatic selection)"
  type        = list(string)
  default     = []
}

variable "public_subnet_count" {
  description = "Number of public subnets to create"
  type        = number
  default     = 2
}

variable "private_subnet_count" {
  description = "Number of private subnets to create"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for all private subnets (cost savings)"
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

# EC2 Variables
variable "key_pair_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string
  default     = "key.pem"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of EC2 instances to launch"
  type        = number
  default     = 1
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH to instances (leave empty to disable SSH)"
  type        = list(string)
  default     = []
}

variable "allowed_http_cidr" {
  description = "CIDR blocks allowed HTTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidr" {
  description = "CIDR blocks allowed HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_public_ip" {
  description = "Associate public IP with instances"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of root volume"
  type        = string
  default     = "gp3"
}

# Monitoring Variables
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "create_sns_topic" {
  description = "Create SNS topic for alarms"
  type        = bool
  default     = false
}

variable "alarm_email_endpoints" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

variable "cpu_threshold" {
  description = "CPU utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "Memory utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
}

variable "disk_threshold" {
  description = "Disk utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
}

variable "enable_memory_monitoring" {
  description = "Enable memory monitoring (requires CloudWatch agent)"
  type        = bool
  default     = true
}

variable "enable_disk_monitoring" {
  description = "Enable disk monitoring (requires CloudWatch agent)"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}

# ALB + ACM Variables
variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for main ALB HTTPS listener"
  type        = string
  default     = "arn:aws:acm:us-east-1:615299732970:certificate/6025f24f-a812-41d9-b97a-cce0f4d4426b"

}

# Ghost Blog Variables
variable "ghost_certificate_arn" {
  description = "ARN of ACM certificate for Ghost blog ALB HTTPS listener"
  type        = string
  default     = "arn:aws:acm:us-east-1:615299732970:certificate/6025f24f-a812-41d9-b97a-cce0f4d4426b"
}

variable "ghost_domain_name" {
  description = "Domain name for Ghost blog (e.g., blog.example.com)"
  type        = string
  default     = "claudiq.com"
}

variable "ghost_image" {
  description = "Docker image for Ghost (e.g., ghost:latest or ghost:5)"
  type        = string
  default     = "ghost:latest"
}

# Observability Variables (Prometheus + Grafana)
variable "enable_observability" {
  description = "Enable Prometheus and Grafana monitoring stack"
  type        = bool
  default     = false
}

variable "grafana_domain_name" {
  description = "Domain name for Grafana (e.g., grafana.example.com)"
  type        = string
  default     = "grafana.claudiq.com"
}

variable "grafana_certificate_arn" {
  description = "ARN of ACM certificate for Grafana HTTPS access"
  type        = string
  default     = ""
}

variable "grafana_admin_password" {
  description = "Grafana admin password (use AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
  default     = "changeme123"
}

variable "prometheus_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 15
}

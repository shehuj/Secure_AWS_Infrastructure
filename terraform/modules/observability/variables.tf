variable "vpc_id" {
  description = "VPC ID where monitoring stack will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks and ALB"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID to deploy monitoring services"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for service discovery"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS access to Grafana"
  type        = string
}

variable "grafana_domain" {
  description = "Domain name for Grafana (e.g., grafana.example.com)"
  type        = string
}

variable "prometheus_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 15
}

variable "grafana_admin_password" {
  description = "Grafana admin password (use AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
  default     = "changeme123"
}

variable "ghost_service_name" {
  description = "Ghost ECS service name for monitoring"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

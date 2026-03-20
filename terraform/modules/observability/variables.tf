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
  description = "Grafana admin password. Stored in Secrets Manager at deploy time. Must be provided via terraform.tfvars or TF_VAR_grafana_admin_password."
  type        = string
  sensitive   = true

  validation {
    condition     = var.grafana_admin_password != ""
    error_message = "grafana_admin_password must not be empty. Set TF_VAR_grafana_admin_password or add it to terraform.tfvars."
  }
}

variable "ghost_service_name" {
  description = "Ghost ECS service name for monitoring"
  type        = string
}

variable "prometheus_allowed_cidrs" {
  description = "CIDR blocks allowed to reach the Prometheus UI via the ALB on port 9090. Restrict to your office/VPN IP range."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

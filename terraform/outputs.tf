# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# ALB + ASG Outputs
output "alb_dns_name" {
  description = "DNS name of the main Application Load Balancer"
  value       = module.alb_asg.alb_dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the main ALB"
  value       = module.alb_asg.alb_zone_id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.alb_asg.asg_name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = module.alb_asg.asg_arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = module.alb_asg.launch_template_id
}

# Ghost Blog Outputs
output "ghost_alb_dns_name" {
  description = "DNS name of the Ghost blog Application Load Balancer"
  value       = module.ghost_blog.alb_dns_name
}

output "ghost_alb_zone_id" {
  description = "Canonical hosted zone ID of the Ghost ALB"
  value       = module.ghost_blog.alb_zone_id
}

output "ghost_ecs_cluster_name" {
  description = "Name of the Ghost ECS cluster"
  value       = module.ghost_blog.ecs_cluster_name
}

output "ghost_ecs_service_name" {
  description = "Name of the Ghost ECS service"
  value       = module.ghost_blog.ecs_service_name
}

output "ghost_task_definition_arn" {
  description = "ARN of the Ghost task definition"
  value       = module.ghost_blog.task_definition_arn
}

# Monitoring Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}

# GitHub OIDC Outputs
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = module.github_oidc.role_arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = module.github_oidc.role_name
}

# Observability Outputs (Prometheus + Grafana)
output "grafana_url" {
  description = "URL to access Grafana dashboard"
  value       = var.enable_observability ? module.observability[0].grafana_url : null
}

output "grafana_alb_dns_name" {
  description = "DNS name of the Grafana ALB"
  value       = var.enable_observability ? module.observability[0].grafana_alb_dns_name : null
}

output "grafana_alb_zone_id" {
  description = "Canonical hosted zone ID of the Grafana ALB"
  value       = var.enable_observability ? module.observability[0].grafana_alb_zone_id : null
}

output "prometheus_endpoint" {
  description = "Internal endpoint for Prometheus"
  value       = var.enable_observability ? module.observability[0].prometheus_endpoint : null
}

output "prometheus_service_name" {
  description = "Name of the Prometheus ECS service"
  value       = var.enable_observability ? module.observability[0].prometheus_service_name : null
}

output "grafana_service_name" {
  description = "Name of the Grafana ECS service"
  value       = var.enable_observability ? module.observability[0].grafana_service_name : null
}

# User Analytics Outputs
output "rum_app_monitor_id" {
  description = "CloudWatch RUM Application Monitor ID"
  value       = var.enable_user_analytics ? module.user_analytics[0].rum_app_monitor_id : null
}

output "rum_javascript_snippet" {
  description = "JavaScript snippet to add to Ghost theme for RUM tracking"
  value       = var.enable_user_analytics ? module.user_analytics[0].rum_javascript_snippet : null
  sensitive   = false
}

output "analytics_api_endpoint" {
  description = "API Gateway endpoint for custom analytics events"
  value       = var.enable_user_analytics ? module.user_analytics[0].analytics_api_endpoint : null
}

output "analytics_dashboard_url" {
  description = "CloudWatch Dashboard URL for user analytics"
  value       = var.enable_user_analytics ? module.user_analytics[0].dashboard_url : null
}

output "analytics_log_groups" {
  description = "CloudWatch Log Groups for analytics data"
  value       = var.enable_user_analytics ? module.user_analytics[0].analytics_log_groups : null
}

output "alb_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  value       = var.enable_user_analytics ? module.user_analytics[0].alb_logs_bucket : null
}

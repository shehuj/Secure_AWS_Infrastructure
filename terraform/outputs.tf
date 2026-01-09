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

# EC2 Outputs
output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = module.ec2.instance_ids
}

output "web_public_ips" {
  description = "List of public IP addresses for web servers"
  value       = module.ec2.public_ips
}

output "web_private_ips" {
  description = "List of private IP addresses for web servers"
  value       = module.ec2.private_ips
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.ec2.security_group_id
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

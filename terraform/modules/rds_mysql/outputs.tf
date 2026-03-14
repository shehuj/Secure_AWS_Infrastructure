# RDS MySQL Module Outputs

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.ghost.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.ghost.arn
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.ghost.endpoint
}

output "db_address" {
  description = "RDS instance address (hostname)"
  value       = aws_db_instance.ghost.address
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.ghost.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.ghost.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.ghost.username
  sensitive   = true
}

output "db_password_secret_arn" {
  description = "ARN of Secrets Manager secret containing DB password"
  value       = aws_secretsmanager_secret.rds_password.arn
}

output "db_security_group_id" {
  description = "Security group ID for RDS instance"
  value       = aws_security_group.rds.id
}

output "db_app_username" {
  description = "Restricted application username (created by Ansible, used by Ghost ECS)"
  value       = var.app_username
}

output "db_app_password_secret_arn" {
  description = "ARN of Secrets Manager secret containing the Ghost app user password"
  value       = aws_secretsmanager_secret.app_user_password.arn
}

output "db_master_secret_name" {
  description = "Secrets Manager secret name for master password (for Ansible)"
  value       = aws_secretsmanager_secret.rds_password.name
}

output "db_app_secret_name" {
  description = "Secrets Manager secret name for app user password (for Ansible)"
  value       = aws_secretsmanager_secret.app_user_password.name
}

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

output "connection_string" {
  description = "MySQL connection string for Ghost"
  value       = "mysql://${aws_db_instance.ghost.username}:PASSWORD@${aws_db_instance.ghost.endpoint}/${aws_db_instance.ghost.db_name}"
  sensitive   = true
}

# ElastiCache Redis Module Outputs

output "redis_replication_group_id" {
  description = "Redis replication group identifier"
  value       = aws_elasticache_replication_group.ghost.id
}

output "redis_primary_endpoint" {
  description = "Primary endpoint for Redis cluster"
  value       = aws_elasticache_replication_group.ghost.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Reader endpoint for Redis cluster (for read replicas)"
  value       = aws_elasticache_replication_group.ghost.reader_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.ghost.port
}

output "redis_auth_token_secret_arn" {
  description = "ARN of Secrets Manager secret containing Redis auth token"
  value       = var.transit_encryption_enabled ? aws_secretsmanager_secret.redis_auth_token[0].arn : null
}

output "redis_security_group_id" {
  description = "Security group ID for Redis cluster"
  value       = aws_security_group.redis.id
}

output "connection_string" {
  description = "Redis connection string for Ghost"
  value       = var.transit_encryption_enabled ? "rediss://:AUTH_TOKEN@${aws_elasticache_replication_group.ghost.primary_endpoint_address}:${aws_elasticache_replication_group.ghost.port}" : "redis://${aws_elasticache_replication_group.ghost.primary_endpoint_address}:${aws_elasticache_replication_group.ghost.port}"
  sensitive   = true
}

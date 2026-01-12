terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}


# ElastiCache Redis for Ghost - Enterprise Caching Layer
# Provides managed Redis for sessions, caching, and performance

# Subnet Group for ElastiCache
resource "aws_elasticache_subnet_group" "ghost" {
  name       = "${var.environment}-ghost-redis-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    {
      Name        = "${var.environment}-ghost-redis-subnet-group"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Security Group for Redis
resource "aws_security_group" "redis" {
  name        = "${var.environment}-ghost-redis-sg"
  description = "Security group for Ghost ElastiCache Redis cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from ECS tasks"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-redis-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Parameter Group for Redis optimization
resource "aws_elasticache_parameter_group" "ghost" {
  name   = "${var.environment}-ghost-redis-params"
  family = var.redis_family

  # Ghost-optimized parameters
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru" # Evict least recently used keys when memory is full
  }

  parameter {
    name  = "timeout"
    value = "300" # Close connections after 5 minutes of idleness
  }

  parameter {
    name  = "tcp-keepalive"
    value = "60"
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-redis-params"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ElastiCache Replication Group (Redis Cluster)
resource "aws_elasticache_replication_group" "ghost" {
  replication_group_id = "${var.environment}-ghost-redis"
  description          = "Redis cluster for Ghost blog caching and sessions"

  engine         = "redis"
  engine_version = var.redis_version
  node_type      = var.node_type

  # Cluster configuration
  num_cache_clusters         = var.num_cache_nodes
  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled           = var.multi_az_enabled

  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.ghost.name
  security_group_ids = [aws_security_group.redis.id]
  port               = 6379

  # Parameter group
  parameter_group_name = aws_elasticache_parameter_group.ghost.name

  # Maintenance
  maintenance_window       = var.maintenance_window
  snapshot_window          = var.snapshot_window
  snapshot_retention_limit = var.snapshot_retention_limit

  # Security
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.transit_encryption_enabled ? random_password.redis_auth_token[0].result : null

  # Automatic minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Notifications
  notification_topic_arn = var.notification_topic_arn

  # Logs
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-redis"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Random auth token for Redis (if encryption in transit is enabled)
resource "random_password" "redis_auth_token" {
  count   = var.transit_encryption_enabled ? 1 : 0
  length  = 32
  special = false # Redis auth token doesn't support special characters
}

# Store Redis auth token in Secrets Manager
resource "aws_secretsmanager_secret" "redis_auth_token" {
  count                   = var.transit_encryption_enabled ? 1 : 0
  name                    = "${var.environment}/ghost/redis/auth-token"
  description             = "Auth token for Ghost Redis cluster"
  recovery_window_in_days = 7

  tags = merge(
    {
      Name        = "${var.environment}-ghost-redis-auth-token"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  count         = var.transit_encryption_enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.redis_auth_token[0].id
  secret_string = random_password.redis_auth_token[0].result
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/${var.environment}/ghost/redis/slow-log"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-ghost-redis-slow-log"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_cloudwatch_log_group" "redis_engine_log" {
  name              = "/aws/elasticache/${var.environment}/ghost/redis/engine-log"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-ghost-redis-engine-log"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# CloudWatch Alarms for Redis
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.environment}-ghost-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "This metric monitors Redis CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.ghost.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.environment}-ghost-redis-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors Redis memory utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.ghost.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${var.environment}-ghost-redis-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000
  alarm_description   = "This metric monitors Redis evictions"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.ghost.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_connections" {
  alarm_name          = "${var.environment}-ghost-redis-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 500
  alarm_description   = "This metric monitors Redis current connections"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.ghost.id
  }

  tags = var.tags
}

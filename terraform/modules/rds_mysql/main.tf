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


# RDS MySQL for Ghost Blog - Enterprise Grade
# Provides managed, highly available MySQL database

# DB Subnet Group
resource "aws_db_subnet_group" "ghost" {
  name       = "${var.environment}-ghost-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    {
      Name        = "${var.environment}-ghost-db-subnet-group"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.environment}-ghost-rds-sg"
  description = "Security group for Ghost RDS MySQL instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from ECS tasks"
    from_port       = 3306
    to_port         = 3306
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
      Name        = "${var.environment}-ghost-rds-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Random password for RDS master user
resource "random_password" "rds_password" {
  length  = 32
  special = true
}

# Store RDS password in Secrets Manager
resource "aws_secretsmanager_secret" "rds_password" {
  name                    = "${var.environment}/ghost/rds/master-password"
  description             = "Master password for Ghost RDS MySQL instance"
  recovery_window_in_days = 7

  tags = merge(
    {
      Name        = "${var.environment}-ghost-rds-password"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id     = aws_secretsmanager_secret.rds_password.id
  secret_string = random_password.rds_password.result
}

# RDS MySQL Instance
resource "aws_db_instance" "ghost" {
  identifier     = "${var.environment}-ghost-db"
  engine         = "mysql"
  engine_version = var.mysql_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  iops                  = var.iops

  db_name  = var.database_name
  username = var.master_username
  password = random_password.rds_password.result

  db_subnet_group_name   = aws_db_subnet_group.ghost.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability
  multi_az          = var.multi_az
  availability_zone = var.multi_az ? null : var.availability_zone

  # Backup Configuration
  backup_retention_period         = var.backup_retention_period
  backup_window                   = var.backup_window
  maintenance_window              = var.maintenance_window
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  # Performance & Monitoring
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  # Deletion Protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.final_snapshot_enabled
  final_snapshot_identifier = var.final_snapshot_enabled ? "${var.environment}-ghost-db-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Enhanced Features
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  copy_tags_to_snapshot      = true
  parameter_group_name       = aws_db_parameter_group.ghost.name

  tags = merge(
    {
      Name        = "${var.environment}-ghost-db"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# DB Parameter Group for MySQL optimization
resource "aws_db_parameter_group" "ghost" {
  name   = "${var.environment}-ghost-mysql-params"
  family = "mysql8.0"

  # Ghost-optimized parameters
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = var.max_connections
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  parameter {
    name  = "log_queries_not_using_indexes"
    value = "1"
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-mysql-params"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.environment}-ghost-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.environment}-ghost-rds-monitoring-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.environment}-ghost-db-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.ghost.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_memory" {
  alarm_name          = "${var.environment}-ghost-db-freeable-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 256000000 # 256 MB in bytes
  alarm_description   = "This metric monitors RDS freeable memory"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.ghost.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_storage" {
  alarm_name          = "${var.environment}-ghost-db-free-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2000000000 # 2 GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.ghost.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.environment}-ghost-db-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.max_connections * 0.8 # 80% of max
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.ghost.id
  }

  tags = var.tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/aws/ec2/${var.environment}/nginx/access"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-nginx-access-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "/aws/ec2/${var.environment}/nginx/error"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-nginx-error-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  count = var.create_sns_topic ? 1 : 0
  name  = "${var.environment}-infrastructure-alarms"

  tags = merge(
    {
      Name        = "${var.environment}-infrastructure-alarms"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count     = var.create_sns_topic && length(var.alarm_email_endpoints) > 0 ? length(var.alarm_email_endpoints) : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email_endpoints[count.index]
}

# EC2 CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  count               = length(var.instance_ids)
  alarm_name          = "${var.environment}-ec2-cpu-high-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  tags = merge(
    {
      Name        = "${var.environment}-ec2-cpu-high-${count.index + 1}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# EC2 Status Check Failed Alarm
resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  count               = length(var.instance_ids)
  alarm_name          = "${var.environment}-ec2-status-check-failed-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "This metric monitors EC2 status checks"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  tags = merge(
    {
      Name        = "${var.environment}-ec2-status-check-failed-${count.index + 1}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Memory Utilization Alarm (requires CloudWatch agent)
resource "aws_cloudwatch_metric_alarm" "ec2_memory_high" {
  count               = var.enable_memory_monitoring ? length(var.instance_ids) : 0
  alarm_name          = "${var.environment}-ec2-memory-high-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "WebServer/${var.environment}"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors EC2 memory utilization"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  tags = merge(
    {
      Name        = "${var.environment}-ec2-memory-high-${count.index + 1}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Disk Utilization Alarm (requires CloudWatch agent)
resource "aws_cloudwatch_metric_alarm" "ec2_disk_high" {
  count               = var.enable_disk_monitoring ? length(var.instance_ids) : 0
  alarm_name          = "${var.environment}-ec2-disk-high-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DiskUtilization"
  namespace           = "WebServer/${var.environment}"
  period              = 300
  statistic           = "Average"
  threshold           = var.disk_threshold
  alarm_description   = "This metric monitors EC2 disk utilization"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  tags = merge(
    {
      Name        = "${var.environment}-ec2-disk-high-${count.index + 1}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  count          = var.create_dashboard ? 1 : 0
  dashboard_name = "${var.environment}-infrastructure-dashboard"

  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type = "metric"
          properties = {
            metrics = [
              for idx, instance_id in var.instance_ids : [
                "AWS/EC2", "CPUUtilization", { stat = "Average", period = 300 },
                { InstanceId = instance_id, label = "Instance ${idx + 1}" }
              ]
            ]
            view    = "timeSeries"
            stacked = false
            region  = data.aws_region.current.id
            title   = "EC2 CPU Utilization"
            period  = 300
          }
        },
        {
          type = "metric"
          properties = {
            metrics = [
              for idx, instance_id in var.instance_ids : [
                "AWS/EC2", "NetworkIn", { stat = "Sum", period = 300 },
                { InstanceId = instance_id, label = "Instance ${idx + 1}" }
              ]
            ]
            view    = "timeSeries"
            stacked = false
            region  = data.aws_region.current.id
            title   = "Network In"
            period  = 300
          }
        },
        {
          type = "metric"
          properties = {
            metrics = [
              for idx, instance_id in var.instance_ids : [
                "AWS/EC2", "NetworkOut", { stat = "Sum", period = 300 },
                { InstanceId = instance_id, label = "Instance ${idx + 1}" }
              ]
            ]
            view    = "timeSeries"
            stacked = false
            region  = data.aws_region.current.id
            title   = "Network Out"
            period  = 300
          }
        }
      ],
      var.enable_memory_monitoring ? [
        {
          type = "metric"
          properties = {
            metrics = [
              for idx, instance_id in var.instance_ids : [
                "WebServer/${var.environment}", "MemoryUtilization", { stat = "Average", period = 300 },
                { InstanceId = instance_id, label = "Instance ${idx + 1}" }
              ]
            ]
            view    = "timeSeries"
            stacked = false
            region  = data.aws_region.current.id
            title   = "Memory Utilization"
            period  = 300
          }
        }
      ] : [],
      var.enable_disk_monitoring ? [
        {
          type = "metric"
          properties = {
            metrics = [
              for idx, instance_id in var.instance_ids : [
                "WebServer/${var.environment}", "DiskUtilization", { stat = "Average", period = 300 },
                { InstanceId = instance_id, label = "Instance ${idx + 1}" }
              ]
            ]
            view    = "timeSeries"
            stacked = false
            region  = data.aws_region.current.id
            title   = "Disk Utilization"
            period  = 300
          }
        }
      ] : []
    )
  })
}

data "aws_region" "current" {}

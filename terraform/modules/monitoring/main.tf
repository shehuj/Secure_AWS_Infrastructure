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

# Old EC2 alarms - replaced by ASG/ALB/ECS alarms
# (Kept commented for reference)

# ASG CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  alarm_name          = "${var.environment}-asg-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors ASG average CPU utilization"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = merge(
    {
      Name        = "${var.environment}-asg-cpu-high"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ALB Target Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.environment}-alb-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = merge(
    {
      Name        = "${var.environment}-alb-response-time-high"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ALB Unhealthy Targets Alarm
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.environment}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "This metric monitors unhealthy targets in the ALB target group"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = merge(
    {
      Name        = "${var.environment}-alb-unhealthy-targets"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Ghost ECS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ghost_cpu_high" {
  alarm_name          = "${var.environment}-ghost-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors Ghost ECS service CPU utilization"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    ServiceName = var.ghost_service_name
    ClusterName = var.ghost_cluster_name
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-cpu-high"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Ghost ECS Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ghost_memory_high" {
  count               = var.enable_memory_monitoring ? 1 : 0
  alarm_name          = "${var.environment}-ghost-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors Ghost ECS service memory utilization"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    ServiceName = var.ghost_service_name
    ClusterName = var.ghost_cluster_name
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-memory-high"
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
    widgets = [
      # ASG Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.id
          title   = "ASG CPU Utilization"
          period  = 300
          stat    = "Average"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", var.asg_name],
            [".", "GroupDesiredCapacity", "AutoScalingGroupName", var.asg_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.id
          title   = "ASG Instance Count"
          period  = 300
          stat    = "Average"
        }
      },
      # ALB Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "Average" }],
            [".", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.id
          title   = "ALB Performance"
          period  = 300
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix],
            [".", "UnHealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Maximum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.id
          title   = "ALB Target Health"
          period  = 300
          stat    = "Average"
        }
      },
      # Ghost ECS Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.ghost_service_name, "ClusterName", var.ghost_cluster_name],
            [".", "MemoryUtilization", "ServiceName", var.ghost_service_name, "ClusterName", var.ghost_cluster_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.id
          title   = "Ghost ECS Service - CPU & Memory"
          period  = 300
          stat    = "Average"
        }
      }
    ]
  })
}

data "aws_region" "current" {}

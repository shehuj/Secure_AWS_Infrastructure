terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# CloudWatch RUM (Real User Monitoring) for Frontend Analytics
resource "aws_rum_app_monitor" "ghost" {
  name   = "${var.environment}-ghost-rum"
  domain = var.domain_name

  app_monitor_configuration {
    allow_cookies         = true
    enable_xray           = true
    session_sample_rate   = var.rum_sample_rate
    telemetries           = ["errors", "performance", "http"]
    favorite_pages        = var.favorite_pages
    excluded_pages        = var.excluded_pages
    included_pages        = var.included_pages

    # Guest user tracking
    guest_role_arn = aws_iam_role.rum_guest.arn

    # Identity pool for user tracking
    identity_pool_id = aws_cognito_identity_pool.rum.id
  }

  # Custom events configuration (at resource level, not in app_monitor_configuration)
  custom_events {
    status = "ENABLED"
  }

  # Send RUM data to CloudWatch Logs
  cw_log_enabled = true

  tags = merge(
    {
      Name        = "${var.environment}-ghost-rum"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Cognito Identity Pool for RUM
resource "aws_cognito_identity_pool" "rum" {
  identity_pool_name               = "${var.environment}_ghost_rum"
  allow_unauthenticated_identities = true
  allow_classic_flow               = false

  tags = merge(
    {
      Name        = "${var.environment}-ghost-rum-identity-pool"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# IAM Role for RUM Guest Users
resource "aws_iam_role" "rum_guest" {
  name = "${var.environment}-ghost-rum-guest-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.rum.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for RUM
resource "aws_iam_role_policy" "rum_guest" {
  name = "rum-access"
  role = aws_iam_role.rum_guest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rum:PutRumEvents"
        ]
        Resource = aws_rum_app_monitor.ghost.arn
      }
    ]
  })
}

# Attach role to identity pool
resource "aws_cognito_identity_pool_roles_attachment" "rum" {
  identity_pool_id = aws_cognito_identity_pool.rum.id

  roles = {
    "unauthenticated" = aws_iam_role.rum_guest.arn
  }
}

# CloudWatch Log Group for RUM Data
resource "aws_cloudwatch_log_group" "rum" {
  name              = "/aws/rum/${var.environment}/ghost"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-ghost-rum-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# CloudWatch Log Group for Custom User Analytics
resource "aws_cloudwatch_log_group" "user_analytics" {
  name              = "/aws/analytics/${var.environment}/ghost/users"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-ghost-user-analytics"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# CloudWatch Log Group for Page Views
resource "aws_cloudwatch_log_group" "pageviews" {
  name              = "/aws/analytics/${var.environment}/ghost/pageviews"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-ghost-pageviews"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# CloudWatch Log Group for User Engagement
resource "aws_cloudwatch_log_group" "engagement" {
  name              = "/aws/analytics/${var.environment}/ghost/engagement"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-ghost-engagement"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Enable ALB Access Logs for detailed visitor information
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.environment}-ghost-alb-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    {
      Name        = "${var.environment}-ghost-alb-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    expiration {
      days = var.alb_log_retention_days
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Policy for ALB Logs
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

# CloudWatch Metric Filters for User Analytics

# Unique Visitors
resource "aws_cloudwatch_log_metric_filter" "unique_visitors" {
  name           = "${var.environment}-ghost-unique-visitors"
  log_group_name = aws_cloudwatch_log_group.pageviews.name
  pattern        = "[timestamp, request_id, visitor_id, ...]"

  metric_transformation {
    name      = "UniqueVisitors"
    namespace = "Ghost/Analytics"
    value     = "1"
    unit      = "Count"
  }
}

# Page Views
resource "aws_cloudwatch_log_metric_filter" "page_views" {
  name           = "${var.environment}-ghost-page-views"
  log_group_name = aws_cloudwatch_log_group.pageviews.name
  pattern        = "[timestamp, request_id, visitor_id, page, ...]"

  metric_transformation {
    name      = "PageViews"
    namespace = "Ghost/Analytics"
    value     = "1"
    unit      = "Count"
  }
}

# Session Duration
resource "aws_cloudwatch_log_metric_filter" "session_duration" {
  name           = "${var.environment}-ghost-session-duration"
  log_group_name = aws_cloudwatch_log_group.engagement.name
  pattern        = "[timestamp, session_id, duration_seconds, ...]"

  metric_transformation {
    name      = "SessionDuration"
    namespace = "Ghost/Analytics"
    value     = "$duration_seconds"
    unit      = "Seconds"
  }
}

# Bounce Rate (Single Page Sessions)
resource "aws_cloudwatch_log_metric_filter" "bounce_rate" {
  name           = "${var.environment}-ghost-bounces"
  log_group_name = aws_cloudwatch_log_group.engagement.name
  pattern        = "[timestamp, session_id, page_count=1, ...]"

  metric_transformation {
    name      = "Bounces"
    namespace = "Ghost/Analytics"
    value     = "1"
    unit      = "Count"
  }
}

# Engagement Score
resource "aws_cloudwatch_log_metric_filter" "engagement_score" {
  name           = "${var.environment}-ghost-engagement"
  log_group_name = aws_cloudwatch_log_group.engagement.name
  pattern        = "[timestamp, visitor_id, engagement_score, ...]"

  metric_transformation {
    name      = "EngagementScore"
    namespace = "Ghost/Analytics"
    value     = "$engagement_score"
    unit      = "None"
  }
}

# Device Type Distribution
resource "aws_cloudwatch_log_metric_filter" "mobile_visitors" {
  name           = "${var.environment}-ghost-mobile-visitors"
  log_group_name = aws_cloudwatch_log_group.user_analytics.name
  pattern        = "[timestamp, visitor_id, device_type=Mobile, ...]"

  metric_transformation {
    name      = "MobileVisitors"
    namespace = "Ghost/Analytics"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "desktop_visitors" {
  name           = "${var.environment}-ghost-desktop-visitors"
  log_group_name = aws_cloudwatch_log_group.user_analytics.name
  pattern        = "[timestamp, visitor_id, device_type=Desktop, ...]"

  metric_transformation {
    name      = "DesktopVisitors"
    namespace = "Ghost/Analytics"
    value     = "1"
    unit      = "Count"
  }
}

# Geographic Distribution
resource "aws_cloudwatch_log_metric_filter" "visitors_by_country" {
  name           = "${var.environment}-ghost-visitors-by-country"
  log_group_name = aws_cloudwatch_log_group.user_analytics.name
  pattern        = "[timestamp, visitor_id, country, ...]"

  metric_transformation {
    name       = "VisitorsByCountry"
    namespace  = "Ghost/Analytics"
    value      = "1"
    unit       = "Count"
    dimensions = {
      Country = "$country"
    }
  }
}

# Comprehensive Analytics Dashboard
resource "aws_cloudwatch_dashboard" "user_analytics" {
  dashboard_name = "${var.environment}-ghost-user-analytics"

  dashboard_body = jsonencode({
    widgets = [
      # Real-time Visitors
      {
        type = "metric"
        properties = {
          metrics = [
            ["Ghost/Analytics", "UniqueVisitors", { stat = "Sum", label = "Unique Visitors" }],
            [".", "PageViews", { stat = "Sum", label = "Page Views" }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.id
          title  = "Real-Time Traffic"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # Session Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["Ghost/Analytics", "SessionDuration", { stat = "Average", label = "Avg Session Duration (s)" }],
            [".", "Bounces", { stat = "Sum", label = "Bounced Sessions" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.id
          title  = "Session Metrics"
        }
      },
      # Device Distribution
      {
        type = "metric"
        properties = {
          metrics = [
            ["Ghost/Analytics", "MobileVisitors", { stat = "Sum", label = "Mobile" }],
            [".", "DesktopVisitors", { stat = "Sum", label = "Desktop" }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.id
          title  = "Device Type Distribution"
          view   = "pie"
        }
      },
      # Engagement
      {
        type = "metric"
        properties = {
          metrics = [
            ["Ghost/Analytics", "EngagementScore", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.id
          title  = "User Engagement Score"
        }
      },
      # RUM Performance Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RUM", "PerformanceNavigationDuration", { appmonitor_name = aws_rum_app_monitor.ghost.name }],
            [".", "PerformanceLargestContentfulPaint", { appmonitor_name = aws_rum_app_monitor.ghost.name }],
            [".", "PerformanceFirstInputDelay", { appmonitor_name = aws_rum_app_monitor.ghost.name }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.id
          title  = "Page Performance (Core Web Vitals)"
        }
      },
      # Error Rate
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RUM", "JsErrorCount", { appmonitor_name = aws_rum_app_monitor.ghost.name, stat = "Sum" }],
            [".", "HttpErrorCount", { appmonitor_name = aws_rum_app_monitor.ghost.name, stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.id
          title  = "Error Rate"
        }
      },
      # Geographic Distribution
      {
        type = "metric"
        properties = {
          metrics = [
            ["Ghost/Analytics", "VisitorsByCountry"]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.id
          title  = "Visitors by Country"
        }
      },
      # Recent Logs
      {
        type = "log"
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.pageviews.name}' | fields @timestamp, visitor_id, page, referrer | sort @timestamp desc | limit 20"
          region  = data.aws_region.current.id
          title   = "Recent Page Views"
        }
      }
    ]
  })
}

# CloudWatch Insights Saved Queries

# Top Pages
resource "aws_cloudwatch_query_definition" "top_pages" {
  name = "${var.environment}-ghost-top-pages"

  log_group_names = [
    aws_cloudwatch_log_group.pageviews.name
  ]

  query_string = <<-QUERY
    fields page
    | stats count() as views by page
    | sort views desc
    | limit 20
  QUERY
}

# Visitor Journey
resource "aws_cloudwatch_query_definition" "visitor_journey" {
  name = "${var.environment}-ghost-visitor-journey"

  log_group_names = [
    aws_cloudwatch_log_group.pageviews.name
  ]

  query_string = <<-QUERY
    fields @timestamp, visitor_id, page, referrer
    | filter visitor_id = "<VISITOR_ID>"
    | sort @timestamp asc
  QUERY
}

# Engagement Analysis
resource "aws_cloudwatch_query_definition" "engagement_analysis" {
  name = "${var.environment}-ghost-engagement-analysis"

  log_group_names = [
    aws_cloudwatch_log_group.engagement.name
  ]

  query_string = <<-QUERY
    fields @timestamp, visitor_id, session_duration, page_count, scroll_depth
    | stats avg(session_duration) as avg_duration,
            avg(page_count) as avg_pages,
            avg(scroll_depth) as avg_scroll
    | limit 1
  QUERY
}

# Traffic Sources
resource "aws_cloudwatch_query_definition" "traffic_sources" {
  name = "${var.environment}-ghost-traffic-sources"

  log_group_names = [
    aws_cloudwatch_log_group.user_analytics.name
  ]

  query_string = <<-QUERY
    fields referrer_domain
    | stats count() as visits by referrer_domain
    | sort visits desc
    | limit 20
  QUERY
}

# Device and Browser Stats
resource "aws_cloudwatch_query_definition" "device_browser_stats" {
  name = "${var.environment}-ghost-device-browser"

  log_group_names = [
    aws_cloudwatch_log_group.user_analytics.name
  ]

  query_string = <<-QUERY
    fields device_type, browser, os
    | stats count() as visits by device_type, browser, os
    | sort visits desc
  QUERY
}

# CloudWatch Alarms for User Activity

# Low Traffic Alert
resource "aws_cloudwatch_metric_alarm" "low_traffic" {
  alarm_name          = "${var.environment}-ghost-low-traffic"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UniqueVisitors"
  namespace           = "Ghost/Analytics"
  period              = 3600
  statistic           = "Sum"
  threshold           = var.low_traffic_threshold
  alarm_description   = "Alert when traffic drops below threshold"
  alarm_actions       = var.alarm_actions

  tags = var.tags
}

# High Error Rate Alert
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.environment}-ghost-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "JsErrorCount"
  namespace           = "AWS/RUM"
  period              = 300
  statistic           = "Sum"
  threshold           = var.high_error_threshold
  alarm_description   = "Alert when JavaScript errors spike"
  alarm_actions       = var.alarm_actions

  dimensions = {
    application_name = aws_rum_app_monitor.ghost.name
  }

  tags = var.tags
}

# Poor Performance Alert
resource "aws_cloudwatch_metric_alarm" "poor_performance" {
  alarm_name          = "${var.environment}-ghost-poor-performance"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "PerformanceNavigationDuration"
  namespace           = "AWS/RUM"
  period              = 300
  statistic           = "Average"
  threshold           = 3000 # 3 seconds
  alarm_description   = "Alert when page load time exceeds 3 seconds"
  alarm_actions       = var.alarm_actions

  dimensions = {
    application_name = aws_rum_app_monitor.ghost.name
  }

  tags = var.tags
}

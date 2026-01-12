# Example: Blue-Green Deployment for ECS
#
# This example shows how to deploy a web application with zero-downtime
# blue-green deployments using the ecs_bluegreen module.

# ============================================
# Prerequisites
# ============================================
# 1. VPC with public subnets
# 2. ACM certificate for HTTPS
# 3. Docker image in ECR or Docker Hub

# ============================================
# Module Usage
# ============================================

module "webapp_blue_green" {
  source = "../modules/ecs_bluegreen"

  # Basic Configuration
  environment = "prod"
  app_name    = "webapp"

  # Network Configuration
  vpc_id = "vpc-xxxxxxxxxxxxx" # Your VPC ID
  subnet_ids = [
    "subnet-xxxxxxxxxxxxx", # Public subnet 1
    "subnet-yyyyyyyyyyyyy"  # Public subnet 2
  ]

  # TLS Certificate
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"

  # Container Configuration
  container_image = "nginx:latest"
  container_port  = 80

  # Resource Allocation
  cpu           = 512  # 0.5 vCPU
  memory        = 1024 # 1 GB
  desired_count = 2    # 2 tasks for HA

  # Security
  trusted_ip_ranges = [
    "0.0.0.0/0" # Allow from anywhere (restrict in production!)
  ]

  # Health Check
  health_check_path    = "/"
  health_check_matcher = "200"

  # Deployment Configuration
  deployment_timeout_minutes    = 15
  termination_wait_time_minutes = 5
  enable_auto_rollback          = true
  enable_deletion_protection    = false # Set true for production

  # Logging
  log_retention_days = 7

  # Environment Variables (Optional)
  container_environment = {
    NODE_ENV  = "production"
    LOG_LEVEL = "info"
    APP_NAME  = "webapp"
  }

  # Secrets (Optional)
  # container_secrets = {
  #   DB_PASSWORD = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password"
  #   API_KEY     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:api-key"
  # }

  # SNS Notifications (Optional)
  # sns_topic_arn = aws_sns_topic.deployments.arn

  tags = {
    Project     = "MyWebApp"
    Environment = "Production"
    Team        = "DevOps"
    ManagedBy   = "Terraform"
  }
}

# ============================================
# Outputs
# ============================================

output "alb_dns_name" {
  description = "ALB DNS name - use this for Route53 alias"
  value       = module.webapp_blue_green.alb_dns_name
}

output "alb_zone_id" {
  description = "ALB Route53 zone ID"
  value       = module.webapp_blue_green.alb_zone_id
}

output "production_url" {
  description = "Production HTTPS URL"
  value       = "https://${module.webapp_blue_green.alb_dns_name}"
}

output "test_url" {
  description = "Test URL for green environment"
  value       = "https://${module.webapp_blue_green.alb_dns_name}:8443"
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = module.webapp_blue_green.cluster_name
}

output "service_name" {
  description = "ECS service name"
  value       = module.webapp_blue_green.service_name
}

output "codedeploy_app_name" {
  description = "CodeDeploy application name"
  value       = module.webapp_blue_green.codedeploy_app_name
}

output "codedeploy_deployment_group" {
  description = "CodeDeploy deployment group name"
  value       = module.webapp_blue_green.codedeploy_deployment_group_name
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = module.webapp_blue_green.log_group_name
}

# ============================================
# Optional: Route53 DNS Record
# ============================================

# data "aws_route53_zone" "main" {
#   name = "example.com"
# }

# resource "aws_route53_record" "webapp" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "webapp.example.com"
#   type    = "A"

#   alias {
#     name                   = module.webapp_blue_green.alb_dns_name
#     zone_id                = module.webapp_blue_green.alb_zone_id
#     evaluate_target_health = true
#   }
# }

# ============================================
# Optional: SNS Topic for Notifications
# ============================================

# resource "aws_sns_topic" "deployments" {
#   name = "webapp-deployments"

#   tags = {
#     Name = "webapp-deployment-notifications"
#   }
# }

# resource "aws_sns_topic_subscription" "email" {
#   topic_arn = aws_sns_topic.deployments.arn
#   protocol  = "email"
#   endpoint  = "devops@example.com"
# }

# ============================================
# Optional: CloudWatch Dashboard
# ============================================

# resource "aws_cloudwatch_dashboard" "webapp" {
#   dashboard_name = "webapp-blue-green"

#   dashboard_body = jsonencode({
#     widgets = [
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
#             [".", "RequestCount", { stat = "Sum" }],
#             [".", "HTTPCode_Target_2XX_Count", { stat = "Sum" }],
#             [".", "HTTPCode_Target_5XX_Count", { stat = "Sum", color = "#d62728" }]
#           ]
#           period = 300
#           stat   = "Average"
#           region = "us-east-1"
#           title  = "ALB Metrics"
#         }
#       },
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
#             [".", "MemoryUtilization", { stat = "Average" }]
#           ]
#           period = 300
#           stat   = "Average"
#           region = "us-east-1"
#           title  = "ECS Task Metrics"
#         }
#       }
#     ]
#   })
# }

# ============================================
# How to Deploy
# ============================================

# 1. Initialize Terraform
#    terraform init

# 2. Review plan
#    terraform plan

# 3. Apply infrastructure
#    terraform apply

# 4. Deploy new version
#    ./scripts/blue-green/deploy.sh -e prod -a webapp -i nginx:1.21

# 5. Monitor deployment
#    ./scripts/blue-green/status.sh -e prod -a webapp --watch

# 6. Rollback if needed
#    ./scripts/blue-green/rollback.sh -e prod -a webapp

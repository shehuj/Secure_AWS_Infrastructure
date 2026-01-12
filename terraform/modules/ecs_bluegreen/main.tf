# terraform/modules/ecs_bluegreen/main.tf
# Blue-Green Deployment for ECS with CodeDeploy

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_region" "current" {}

# ============================================
# CloudWatch Logs
# ============================================

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.environment}/${var.app_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ============================================
# ECS Cluster
# ============================================

resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-cluster"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ============================================
# Security Groups
# ============================================

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.environment}-${var.app_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from trusted IPs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.trusted_ip_ranges
  }

  ingress {
    description = "HTTP from trusted IPs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.trusted_ip_ranges
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-alb-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ECS Tasks Security Group
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-${var.app_name}-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-tasks-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ============================================
# Application Load Balancer
# ============================================

resource "aws_lb" "main" {
  name               = "${var.environment}-${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true
  drop_invalid_header_fields       = true

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-alb"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Blue Target Group
resource "aws_lb_target_group" "blue" {
  name        = "${var.environment}-${var.app_name}-blue-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = var.health_check_matcher
  }

  deregistration_delay = 30

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-blue-tg"
      Environment = var.environment
      Color       = "Blue"
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Green Target Group
resource "aws_lb_target_group" "green" {
  name        = "${var.environment}-${var.app_name}-green-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = var.health_check_matcher
  }

  deregistration_delay = 30

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-green-tg"
      Environment = var.environment
      Color       = "Green"
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS Listener (Production Traffic)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-https-listener"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    ignore_changes = [default_action]
  }
}

# HTTP Listener (Redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-http-listener"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Test Listener for Blue-Green Testing
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.main.arn
  port              = "8443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-test-listener"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    ignore_changes = [default_action]
  }
}

# ============================================
# IAM Roles
# ============================================

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.environment}-${var.app_name}-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-task-exec-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for secrets access (if secrets are used)
resource "aws_iam_policy" "secrets_access" {
  count = length(var.container_secrets) > 0 ? 1 : 0

  name        = "${var.environment}-${var.app_name}-secrets-access"
  description = "Allow ECS tasks to access secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  count = length(var.container_secrets) > 0 ? 1 : 0

  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.secrets_access[0].arn
}

# ECS Task Role (Application Permissions)
resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-${var.app_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-task-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# CodeDeploy IAM Role
resource "aws_iam_role" "codedeploy" {
  name = "${var.environment}-${var.app_name}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-codedeploy-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# ============================================
# ECS Task Definition
# ============================================

locals {
  environment_variables = [
    for k, v in var.container_environment : {
      name  = k
      value = v
    }
  ]

  secrets = [
    for k, v in var.container_secrets : {
      name      = k
      valueFrom = v
    }
  ]
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.environment}-${var.app_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = local.environment_variables
      secrets     = local.secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.app_name
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-task"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ============================================
# ECS Service with CODE_DEPLOY
# ============================================

resource "aws_ecs_service" "main" {
  name            = "${var.environment}-${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = var.app_name
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener.http,
    aws_lb_listener.test
  ]

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-service"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer,
      desired_count
    ]
  }
}

# ============================================
# CodeDeploy Configuration
# ============================================

# CodeDeploy Application
resource "aws_codedeploy_app" "main" {
  compute_platform = "ECS"
  name             = "${var.environment}-${var.app_name}"

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-codedeploy"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "${var.environment}-${var.app_name}-dg"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  auto_rollback_configuration {
    enabled = var.enable_auto_rollback
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = var.termination_wait_time_minutes
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.main.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.https.arn]
      }

      test_traffic_route {
        listener_arns = [aws_lb_listener.test.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  dynamic "trigger_configuration" {
    for_each = var.sns_topic_arn != "" ? [1] : []

    content {
      trigger_events = [
        "DeploymentStart",
        "DeploymentSuccess",
        "DeploymentFailure",
        "DeploymentStop",
        "DeploymentRollback"
      ]
      trigger_name       = "${var.environment}-${var.app_name}-deployment"
      trigger_target_arn = var.sns_topic_arn
    }
  }

  tags = merge(
    {
      Name        = "${var.environment}-${var.app_name}-deployment-group"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

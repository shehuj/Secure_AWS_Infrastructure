# CloudWatch Log Group for Ghost container logs
resource "aws_cloudwatch_log_group" "ghost" {
  name              = "/ecs/${var.environment}/ghost"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name        = "${var.environment}-ghost-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ECS Cluster
resource "aws_ecs_cluster" "ghost" {
  name = "${var.environment}-ghost-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-cluster"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.environment}-ghost-task-execution-role"

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
      Name        = "${var.environment}-ghost-task-execution-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task (application permissions)
resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-ghost-task-role"

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
      Name        = "${var.environment}-ghost-task-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Custom policy for Ghost task (CloudWatch logs, etc.)
resource "aws_iam_policy" "ghost_task" {
  name        = "${var.environment}-ghost-task-policy"
  description = "Policy for Ghost ECS task"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.environment}-ghost-task-policy"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "ghost_task" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ghost_task.arn
}

# Security Group for Ghost ALB
resource "aws_security_group" "ghost_alb" {
  name        = "${var.environment}-ghost-alb-sg"
  description = "Security group for Ghost Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
      Name        = "${var.environment}-ghost-alb-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Security Group for Ghost ECS Tasks
resource "aws_security_group" "ghost_tasks" {
  name        = "${var.environment}-ghost-tasks-sg"
  description = "Security group for Ghost ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Ghost port from ALB"
    from_port       = 2368
    to_port         = 2368
    protocol        = "tcp"
    security_groups = [aws_security_group.ghost_alb.id]
  }

  egress {
    description = "All outbound traffic (for Docker image pull, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-tasks-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ECS Task Definition
resource "aws_ecs_task_definition" "ghost" {
  family                   = "${var.environment}-ghost"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "ghost"
      image     = var.ghost_image
      essential = true

      portMappings = [
        {
          containerPort = 2368
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "url"
          value = "https://${var.ghost_domain}"
        },
        {
          name  = "database__client"
          value = "sqlite3"
        },
        {
          name  = "database__connection__filename"
          value = "/var/lib/ghost/content/data/ghost.db"
        },
        {
          name  = "NODE_ENV"
          value = "production"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ghost.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "ghost"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:2368/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    {
      Name        = "${var.environment}-ghost-task"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Application Load Balancer for Ghost
resource "aws_lb" "ghost" {
  name               = "${var.environment}-ghost-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ghost_alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    {
      Name        = "${var.environment}-ghost-alb"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Target Group for Ghost
resource "aws_lb_target_group" "ghost" {
  name        = "${var.environment}-ghost-tg"
  port        = 2368
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    {
      Name        = "${var.environment}-ghost-target-group"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# HTTPS Listener for Ghost ALB
resource "aws_lb_listener" "ghost_https" {
  load_balancer_arn = aws_lb.ghost.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ghost.arn
  }

  tags = merge(
    {
      Name        = "${var.environment}-ghost-alb-https-listener"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# HTTP Listener for Ghost ALB (redirect to HTTPS)
resource "aws_lb_listener" "ghost_http" {
  load_balancer_arn = aws_lb.ghost.arn
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
      Name        = "${var.environment}-ghost-alb-http-listener"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ECS Service
resource "aws_ecs_service" "ghost" {
  name            = "${var.environment}-ghost-service"
  cluster         = aws_ecs_cluster.ghost.id
  task_definition = aws_ecs_task_definition.ghost.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ghost_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ghost.arn
    container_name   = "ghost"
    container_port   = 2368
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.ghost_https,
    aws_lb_listener.ghost_http
  ]

  tags = merge(
    {
      Name        = "${var.environment}-ghost-service"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Data source for current region
data "aws_region" "current" {}

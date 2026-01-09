# Data sources
data "aws_region" "current" {}

# Security Group for Grafana ALB
resource "aws_security_group" "grafana_alb" {
  name        = "${var.environment}-grafana-alb-sg"
  description = "Security group for Grafana ALB"
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
      Name        = "${var.environment}-grafana-alb-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Security Group for Prometheus/Grafana tasks
resource "aws_security_group" "monitoring_tasks" {
  name        = "${var.environment}-monitoring-tasks-sg"
  description = "Security group for Prometheus and Grafana ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Grafana from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.grafana_alb.id]
  }

  ingress {
    description = "Prometheus from Grafana"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "CloudWatch Exporter"
    from_port   = 9106
    to_port     = 9106
    protocol    = "tcp"
    self        = true
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
      Name        = "${var.environment}-monitoring-tasks-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Security Group for EFS
resource "aws_security_group" "monitoring_efs" {
  name        = "${var.environment}-monitoring-efs-sg"
  description = "Security group for monitoring EFS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from monitoring tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_tasks.id]
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
      Name        = "${var.environment}-monitoring-efs-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# EFS for Prometheus data
resource "aws_efs_file_system" "prometheus" {
  creation_token   = "${var.environment}-prometheus-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(
    {
      Name        = "${var.environment}-prometheus-efs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# EFS Mount Targets for Prometheus
resource "aws_efs_mount_target" "prometheus" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.prometheus.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.monitoring_efs.id]
}

# EFS Access Point for Prometheus
resource "aws_efs_access_point" "prometheus" {
  file_system_id = aws_efs_file_system.prometheus.id

  root_directory {
    path = "/prometheus"
    creation_info {
      owner_gid   = 65534
      owner_uid   = 65534
      permissions = "755"
    }
  }

  posix_user {
    gid = 65534
    uid = 65534
  }

  tags = merge(
    {
      Name        = "${var.environment}-prometheus-access-point"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# EFS for Grafana data
resource "aws_efs_file_system" "grafana" {
  creation_token   = "${var.environment}-grafana-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(
    {
      Name        = "${var.environment}-grafana-efs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# EFS Mount Targets for Grafana
resource "aws_efs_mount_target" "grafana" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.grafana.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.monitoring_efs.id]
}

# EFS Access Point for Grafana
resource "aws_efs_access_point" "grafana" {
  file_system_id = aws_efs_file_system.grafana.id

  root_directory {
    path = "/grafana"
    creation_info {
      owner_gid   = 472
      owner_uid   = 472
      permissions = "755"
    }
  }

  posix_user {
    gid = 472
    uid = 472
  }

  tags = merge(
    {
      Name        = "${var.environment}-grafana-access-point"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.environment}-monitoring-task-execution-role"

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
      Name        = "${var.environment}-monitoring-task-execution-role"
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

# IAM Role for Prometheus task
resource "aws_iam_role" "prometheus_task" {
  name = "${var.environment}-prometheus-task-role"

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
      Name        = "${var.environment}-prometheus-task-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# IAM Policy for Prometheus (ECS Service Discovery)
resource "aws_iam_policy" "prometheus_ecs_discovery" {
  name        = "${var.environment}-prometheus-ecs-discovery"
  description = "Allow Prometheus to discover ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeContainerInstances",
          "ecs:DescribeTaskDefinition",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.environment}-prometheus-ecs-discovery"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "prometheus_ecs_discovery" {
  role       = aws_iam_role.prometheus_task.name
  policy_arn = aws_iam_policy.prometheus_ecs_discovery.arn
}

# CloudWatch Logs for Prometheus
resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/${var.environment}/prometheus"
  retention_in_days = 7

  tags = merge(
    {
      Name        = "${var.environment}-prometheus-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# CloudWatch Logs for Grafana
resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.environment}/grafana"
  retention_in_days = 7

  tags = merge(
    {
      Name        = "${var.environment}-grafana-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Prometheus Configuration (stored as SSM Parameter)
resource "aws_ssm_parameter" "prometheus_config" {
  name        = "/${var.environment}/prometheus/config"
  description = "Prometheus configuration"
  type        = "String"
  value = templatefile("${path.module}/prometheus.yml.tpl", {
    region              = data.aws_region.current.name
    ecs_cluster_name    = var.ecs_cluster_name
    ghost_service_name  = var.ghost_service_name
    retention_days      = var.prometheus_retention_days
  })

  tags = merge(
    {
      Name        = "${var.environment}-prometheus-config"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ECS Task Definition for Prometheus
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.environment}-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.prometheus_task.arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      essential = true

      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--storage.tsdb.retention.time=${var.prometheus_retention_days}d",
        "--web.console.libraries=/usr/share/prometheus/console_libraries",
        "--web.console.templates=/usr/share/prometheus/consoles"
      ]

      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "prometheus-data"
          containerPath = "/prometheus"
          readOnly      = false
        },
        {
          sourceVolume  = "prometheus-config"
          containerPath = "/etc/prometheus"
          readOnly      = true
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "prometheus"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9090/-/healthy || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  volume {
    name = "prometheus-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.prometheus.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus.id
        iam             = "DISABLED"
      }
    }
  }

  volume {
    name = "prometheus-config"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.prometheus.id
      transit_encryption = "ENABLED"
      root_directory     = "/config"
    }
  }

  tags = merge(
    {
      Name        = "${var.environment}-prometheus-task"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ECS Task Definition for Grafana
resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.environment}-grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
      essential = true

      environment = [
        {
          name  = "GF_SERVER_ROOT_URL"
          value = "https://${var.grafana_domain}"
        },
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = var.grafana_admin_password
        },
        {
          name  = "GF_INSTALL_PLUGINS"
          value = "grafana-clock-panel,grafana-simple-json-datasource"
        }
      ]

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "grafana-data"
          containerPath = "/var/lib/grafana"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "grafana"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  volume {
    name = "grafana-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.grafana.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.grafana.id
        iam             = "DISABLED"
      }
    }
  }

  tags = merge(
    {
      Name        = "${var.environment}-grafana-task"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ALB for Grafana
resource "aws_lb" "grafana" {
  name               = "${var.environment}-grafana-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.grafana_alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    {
      Name        = "${var.environment}-grafana-alb"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Target Group for Grafana
resource "aws_lb_target_group" "grafana" {
  name        = "${var.environment}-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    {
      Name        = "${var.environment}-grafana-target-group"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# HTTPS Listener for Grafana ALB
resource "aws_lb_listener" "grafana_https" {
  load_balancer_arn = aws_lb.grafana.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  tags = merge(
    {
      Name        = "${var.environment}-grafana-alb-https-listener"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# HTTP Listener for Grafana ALB (redirect to HTTPS)
resource "aws_lb_listener" "grafana_http" {
  load_balancer_arn = aws_lb.grafana.arn
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
      Name        = "${var.environment}-grafana-alb-http-listener"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ECS Service for Prometheus
resource "aws_ecs_service" "prometheus" {
  name            = "${var.environment}-prometheus-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.monitoring_tasks.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.prometheus.arn
  }

  depends_on = [
    aws_efs_mount_target.prometheus
  ]

  tags = merge(
    {
      Name        = "${var.environment}-prometheus-service"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ECS Service for Grafana
resource "aws_ecs_service" "grafana" {
  name            = "${var.environment}-grafana-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.monitoring_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.grafana_https,
    aws_lb_listener.grafana_http,
    aws_efs_mount_target.grafana
  ]

  tags = merge(
    {
      Name        = "${var.environment}-grafana-service"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "monitoring" {
  name        = "${var.environment}.local"
  description = "Service discovery namespace for monitoring"
  vpc         = var.vpc_id

  tags = merge(
    {
      Name        = "${var.environment}-monitoring-namespace"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Service Discovery Service for Prometheus
resource "aws_service_discovery_service" "prometheus" {
  name = "prometheus"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = merge(
    {
      Name        = "${var.environment}-prometheus-discovery"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

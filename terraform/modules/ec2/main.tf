# Get latest Amazon Linux 2023 AMI if not specified
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
}

# Security Group
resource "aws_security_group" "web" {
  name        = "${var.environment}-web-sg"
  description = "Security group for web servers"
  vpc_id      = var.vpc_id

  # SSH access (restricted)
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidr) > 0 ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidr
      description = "SSH access"
    }
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
    description = "HTTP access"
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_https_cidr
    description = "HTTPS access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    {
      Name        = "${var.environment}-web-sg"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# IAM Role for EC2
resource "aws_iam_role" "ec2" {
  count = var.create_iam_instance_profile ? 1 : 0
  name  = "${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.environment}-ec2-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Attach SSM policy for Systems Manager access
resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.create_iam_instance_profile ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy for logging
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count      = var.create_iam_instance_profile ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom IAM policy for EC2
resource "aws_iam_role_policy" "ec2_custom" {
  count = var.create_iam_instance_profile ? 1 : 0
  name  = "${var.environment}-ec2-custom-policy"
  role  = aws_iam_role.ec2[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  count = var.create_iam_instance_profile ? 1 : 0
  name  = "${var.environment}-ec2-instance-profile"
  role  = aws_iam_role.ec2[0].name

  tags = merge(
    {
      Name        = "${var.environment}-ec2-instance-profile"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# EC2 Instances
resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair
  subnet_id              = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = var.create_iam_instance_profile ? aws_iam_instance_profile.ec2[0].name : null

  associate_public_ip_address = var.enable_public_ip
  monitoring                  = var.enable_detailed_monitoring

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
  }))

  tags = merge(
    {
      Name        = "${var.environment}-web-server-${count.index + 1}"
      Role        = "web"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  volume_tags = merge(
    {
      Name        = "${var.environment}-web-server-${count.index + 1}-root"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

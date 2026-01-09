# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, max(var.public_subnet_count, var.private_subnet_count))
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    {
      Name        = "${var.environment}-vpc"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    # Prevent accidental destruction of VPC
    prevent_destroy = false # Set to true in production
    # Ignore changes to tags added by AWS or other tools
    ignore_changes = [
      tags["Created"],
      tags["Modified"]
    ]
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name        = "${var.environment}-igw"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = element(local.azs, count.index)
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name        = "${var.environment}-public-subnet-${count.index + 1}"
      Type        = "public"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    # Create new subnet before destroying old one
    create_before_destroy = true
    # Ignore AWS-managed tags
    ignore_changes = [tags["Created"]]
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = var.private_subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + var.public_subnet_count)
  availability_zone = element(local.azs, count.index)

  tags = merge(
    {
      Name        = "${var.environment}-private-subnet-${count.index + 1}"
      Type        = "private"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags["Created"]]
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.private_subnet_count) : 0
  domain = "vpc"

  tags = merge(
    {
      Name        = "${var.environment}-nat-eip-${count.index + 1}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.private_subnet_count) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    {
      Name        = "${var.environment}-nat-gw-${count.index + 1}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name        = "${var.environment}-public-rt"
      Type        = "public"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Public Route to Internet Gateway
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count          = var.public_subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count  = var.private_subnet_count
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name        = "${var.environment}-private-rt-${count.index + 1}"
      Type        = "private"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Private Routes to NAT Gateway
resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? var.private_subnet_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count          = var.private_subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${var.environment}-flow-logs"
  retention_in_days = 30

  tags = merge(
    {
      Name        = "${var.environment}-vpc-flow-logs"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.environment}-vpc-flow-logs-role"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.environment}-vpc-flow-logs-policy"
  role  = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  count                = var.enable_flow_logs ? 1 : 0
  iam_role_arn         = aws_iam_role.vpc_flow_logs[0].arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  log_destination_type = "cloud-watch-logs"

  tags = merge(
    {
      Name        = "${var.environment}-vpc-flow-log"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

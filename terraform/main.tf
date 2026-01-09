# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  environment          = var.environment
  availability_zones   = var.availability_zones
  public_subnet_count  = var.public_subnet_count
  private_subnet_count = var.private_subnet_count
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_flow_logs     = var.enable_vpc_flow_logs

  tags = var.tags
}

# EC2 Module
module "ec2" {
  source = "./modules/ec2"

  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.public_subnet_ids
  key_pair             = var.key_pair_name
  instance_type        = var.instance_type
  instance_count       = var.instance_count
  environment          = var.environment
  allowed_ssh_cidr     = var.allowed_ssh_cidr
  allowed_http_cidr    = var.allowed_http_cidr
  allowed_https_cidr   = var.allowed_https_cidr
  enable_public_ip     = var.enable_public_ip
  root_volume_size     = var.root_volume_size
  root_volume_type     = var.root_volume_type

  tags = var.tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  environment             = var.environment
  instance_ids            = module.ec2.instance_ids
  log_retention_days      = var.log_retention_days
  create_sns_topic        = var.create_sns_topic
  alarm_email_endpoints   = var.alarm_email_endpoints
  cpu_threshold           = var.cpu_threshold
  memory_threshold        = var.memory_threshold
  disk_threshold          = var.disk_threshold
  enable_memory_monitoring = var.enable_memory_monitoring
  enable_disk_monitoring   = var.enable_disk_monitoring
  create_dashboard        = var.create_dashboard

  tags = var.tags

  depends_on = [module.ec2]
}

# GitHub OIDC Module
module "github_oidc" {
  source = "./modules/oidc_role"

  repo                    = var.github_repo
  role_name               = "${var.environment}-GitHubActionsRole"
  github_repositories     = ["repo:${var.github_repo}:*"]
  environment             = var.environment
  terraform_state_bucket  = var.terraform_state_bucket
  terraform_lock_table    = var.terraform_lock_table
  attach_readonly_policy  = false
}

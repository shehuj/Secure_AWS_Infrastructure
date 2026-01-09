module "vpc" {
  source = "./modules/vpc"
}

module "ec2" {
  source       = "./modules/ec2"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids
  key_pair     = var.key_pair_name
}

module "github_oidc" {
  source = "./modules/oidc_role"
  repo   = var.github_repo
}
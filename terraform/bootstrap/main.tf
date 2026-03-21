module "github_oidc" {
  source = "../modules/oidc_role"

  repo                   = var.github_repo
  role_name              = "${var.environment}-GitHubActionsRole"
  github_repositories    = ["repo:${var.github_repo}:*"]
  environment            = var.environment
  terraform_state_bucket = var.terraform_state_bucket
  terraform_lock_table   = var.terraform_lock_table
  attach_readonly_policy = false
  create_oidc_provider   = true
}

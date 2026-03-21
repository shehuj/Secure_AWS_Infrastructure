output "role_arn" {
  description = "ARN of the GitHub Actions IAM role — set this as AWS_ROLE_ARN in GitHub secrets"
  value       = module.github_oidc.role_arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = module.github_oidc.oidc_provider_arn
}

output "bootstrap_user_name" {
  description = "Bootstrap IAM user — create an access key and store as AWS_BOOTSTRAP_ACCESS_KEY_ID / AWS_BOOTSTRAP_SECRET_ACCESS_KEY in GitHub secrets"
  value       = module.github_oidc.bootstrap_user_name
}

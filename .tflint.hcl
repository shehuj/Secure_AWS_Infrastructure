# TFLint configuration for idempotency and best practices

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.29.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Enforce lifecycle rules
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

# Naming conventions
rule "terraform_naming_convention" {
  enabled = true

  format = "snake_case"
}

# Best practices for idempotency
rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# AWS specific rules
rule "aws_resource_missing_tags" {
  enabled = true
  tags = ["Environment", "ManagedBy"]
}

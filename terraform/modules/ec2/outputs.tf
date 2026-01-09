output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.web[*].id
}

output "public_ips" {
  description = "List of public IP addresses"
  value       = aws_instance.web[*].public_ip
}

output "private_ips" {
  description = "List of private IP addresses"
  value       = aws_instance.web[*].private_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.web.id
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = try(aws_iam_instance_profile.ec2[0].arn, "")
}

output "instance_role_arn" {
  description = "ARN of the IAM role"
  value       = try(aws_iam_role.ec2[0].arn, "")
}

output "instance_role_name" {
  description = "Name of the IAM role"
  value       = try(aws_iam_role.ec2[0].name, "")
}

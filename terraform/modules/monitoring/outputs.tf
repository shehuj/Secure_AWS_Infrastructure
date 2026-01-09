output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = try(aws_sns_topic.alarms[0].arn, "")
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = try(aws_cloudwatch_dashboard.main[0].dashboard_name, "")
}

output "log_group_names" {
  description = "Names of CloudWatch log groups"
  value = {
    nginx_access = aws_cloudwatch_log_group.nginx_access.name
    nginx_error  = aws_cloudwatch_log_group.nginx_error.name
  }
}

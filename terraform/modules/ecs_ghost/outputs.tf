output "alb_dns_name" {
  description = "DNS name of the Ghost ALB"
  value       = aws_lb.ghost.dns_name
}

output "alb_arn" {
  description = "ARN of the Ghost ALB"
  value       = aws_lb.ghost.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Ghost ALB (for CloudWatch metrics)"
  value       = aws_lb.ghost.arn_suffix
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Ghost ALB"
  value       = aws_lb.ghost.zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.ghost.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.ghost.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.ghost.name
}

output "ecs_service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.ghost.id
}

output "task_definition_arn" {
  description = "ARN of the Ghost task definition"
  value       = aws_ecs_task_definition.ghost.arn
}

output "task_definition_family" {
  description = "Family of the Ghost task definition"
  value       = aws_ecs_task_definition.ghost.family
}

output "target_group_arn" {
  description = "ARN of the Ghost target group"
  value       = aws_lb_target_group.ghost.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the Ghost target group (for CloudWatch metrics)"
  value       = aws_lb_target_group.ghost.arn_suffix
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Ghost logs"
  value       = aws_cloudwatch_log_group.ghost.name
}

output "alb_security_group_id" {
  description = "ID of the Ghost ALB security group"
  value       = aws_security_group.ghost_alb.id
}

output "task_security_group_id" {
  description = "ID of the Ghost ECS task security group"
  value       = aws_security_group.ghost_tasks.id
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

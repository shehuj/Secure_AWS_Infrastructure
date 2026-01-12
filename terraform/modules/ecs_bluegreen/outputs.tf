# terraform/modules/ecs_bluegreen/outputs.tf

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.main.id
}

output "task_definition_arn" {
  description = "Latest task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  description = "Task definition family"
  value       = aws_ecs_task_definition.main.family
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "ALB Route 53 zone ID"
  value       = aws_lb.main.zone_id
}

output "blue_target_group_name" {
  description = "Blue target group name"
  value       = aws_lb_target_group.blue.name
}

output "blue_target_group_arn" {
  description = "Blue target group ARN"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_name" {
  description = "Green target group name"
  value       = aws_lb_target_group.green.name
}

output "green_target_group_arn" {
  description = "Green target group ARN"
  value       = aws_lb_target_group.green.arn
}

output "production_listener_arn" {
  description = "Production (HTTPS) listener ARN"
  value       = aws_lb_listener.https.arn
}

output "test_listener_arn" {
  description = "Test listener ARN (port 8443)"
  value       = aws_lb_listener.test.arn
}

output "codedeploy_app_name" {
  description = "CodeDeploy application name"
  value       = aws_codedeploy_app.main.name
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = aws_codedeploy_deployment_group.main.deployment_group_name
}

output "codedeploy_app_id" {
  description = "CodeDeploy application ID"
  value       = aws_codedeploy_app.main.id
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.app.name
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

output "codedeploy_role_arn" {
  description = "CodeDeploy role ARN"
  value       = aws_iam_role.codedeploy.arn
}

output "security_group_alb_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "security_group_ecs_tasks_id" {
  description = "ECS tasks security group ID"
  value       = aws_security_group.ecs_tasks.id
}

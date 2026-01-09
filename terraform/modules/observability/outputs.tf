output "grafana_alb_dns_name" {
  description = "DNS name of the Grafana ALB"
  value       = aws_lb.grafana.dns_name
}

output "grafana_alb_zone_id" {
  description = "Canonical hosted zone ID of the Grafana ALB"
  value       = aws_lb.grafana.zone_id
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "https://${var.grafana_domain}"
}

output "prometheus_service_name" {
  description = "Name of the Prometheus ECS service"
  value       = aws_ecs_service.prometheus.name
}

output "grafana_service_name" {
  description = "Name of the Grafana ECS service"
  value       = aws_ecs_service.grafana.name
}

output "prometheus_efs_id" {
  description = "ID of the Prometheus EFS file system"
  value       = aws_efs_file_system.prometheus.id
}

output "grafana_efs_id" {
  description = "ID of the Grafana EFS file system"
  value       = aws_efs_file_system.grafana.id
}

output "prometheus_endpoint" {
  description = "Internal endpoint for Prometheus"
  value       = "prometheus.${var.environment}.local:9090"
}

output "grafana_admin_password" {
  description = "Grafana admin password (sensitive)"
  value       = var.grafana_admin_password
  sensitive   = true
}

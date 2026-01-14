output "rum_app_monitor_id" {
  description = "CloudWatch RUM Application Monitor ID"
  value       = aws_rum_app_monitor.ghost.id
}

output "rum_app_monitor_arn" {
  description = "CloudWatch RUM Application Monitor ARN"
  value       = aws_rum_app_monitor.ghost.arn
}

output "rum_identity_pool_id" {
  description = "Cognito Identity Pool ID for RUM"
  value       = aws_cognito_identity_pool.rum.id
}

output "rum_guest_role_arn" {
  description = "IAM Role ARN for RUM guest access"
  value       = aws_iam_role.rum_guest.arn
}

output "rum_javascript_snippet" {
  description = "JavaScript snippet to add to Ghost theme"
  value       = <<-EOT
    <!-- AWS CloudWatch RUM -->
    <script>
      (function(n,i,v,r,s,c,x,z){x=window.AwsRumClient={q:[],n:n,i:i,v:v,r:r,c:c};window[n]=function(c,p){x.q.push({c:c,p:p});};z=document.createElement('script');z.async=true;z.src=s;document.head.insertBefore(z,document.head.getElementsByTagName('script')[0]);})(
        'cwr',
        '${aws_rum_app_monitor.ghost.id}',
        '1.0.0',
        '${data.aws_region.current.id}',
        'https://client.rum.us-east-1.amazonaws.com/1.x/cwr.js',
        {
          sessionSampleRate: ${var.rum_sample_rate},
          guestRoleArn: '${aws_iam_role.rum_guest.arn}',
          identityPoolId: '${aws_cognito_identity_pool.rum.id}',
          endpoint: 'https://dataplane.rum.${data.aws_region.current.id}.amazonaws.com',
          telemetries: ['performance', 'errors', 'http'],
          allowCookies: true,
          enableXRay: true
        }
      );
    </script>
  EOT
}

output "analytics_log_groups" {
  description = "CloudWatch Log Groups for analytics"
  value = {
    rum            = aws_cloudwatch_log_group.rum.name
    user_analytics = aws_cloudwatch_log_group.user_analytics.name
    pageviews      = aws_cloudwatch_log_group.pageviews.name
    engagement     = aws_cloudwatch_log_group.engagement.name
  }
}

output "alb_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  value       = aws_s3_bucket.alb_logs.bucket
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.id}#dashboards:name=${aws_cloudwatch_dashboard.user_analytics.dashboard_name}"
}

output "insights_queries" {
  description = "CloudWatch Insights Saved Queries"
  value = {
    top_pages           = aws_cloudwatch_query_definition.top_pages.name
    visitor_journey     = aws_cloudwatch_query_definition.visitor_journey.name
    engagement_analysis = aws_cloudwatch_query_definition.engagement_analysis.name
    traffic_sources     = aws_cloudwatch_query_definition.traffic_sources.name
    device_browser      = aws_cloudwatch_query_definition.device_browser_stats.name
  }
}

output "analytics_api_id" {
  description = "API Gateway ID for analytics endpoint"
  value       = aws_apigatewayv2_api.analytics.id
}

output "analytics_api_endpoint" {
  description = "Full API Gateway endpoint URL for analytics tracking"
  value       = "${aws_apigatewayv2_api.analytics.api_endpoint}/track"
}

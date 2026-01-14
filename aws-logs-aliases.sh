#!/bin/bash
# AWS CloudWatch Logs - Convenient Aliases
# Source this file: source aws-logs-aliases.sh

# Current logs
alias logs-ecs='aws logs tail /aws/ecs/containerinsights/prod-ghost-cluster/performance --follow'
alias logs-ecs-errors='aws logs tail /aws/ecs/containerinsights/prod-ghost-cluster/performance --follow --filter-pattern ERROR'

# Future analytics logs (after deployment)
alias logs-pageviews='aws logs tail /aws/analytics/prod/ghost/pageviews --follow'
alias logs-engagement='aws logs tail /aws/analytics/prod/ghost/engagement --follow'
alias logs-user='aws logs tail /aws/analytics/prod/ghost/user_analytics --follow'
alias logs-lambda='aws logs tail /aws/lambda/prod-ghost-analytics-processor --follow'
alias logs-lambda-errors='aws logs tail /aws/lambda/prod-ghost-analytics-processor --follow --filter-pattern ERROR'

# Filtered queries
alias logs-bookings='aws logs tail /aws/analytics/prod/ghost/user_analytics --follow --filter-pattern booking'
alias logs-mobile='aws logs tail /aws/analytics/prod/ghost/pageviews --follow --filter-pattern Mobile'
alias logs-errors-all='aws logs tail /aws/lambda/prod-ghost-analytics-processor --filter-pattern ERROR --since 24h'

# List commands
alias logs-list='aws logs describe-log-groups --query "logGroups[*].logGroupName" --output table'
alias logs-list-all='aws logs describe-log-groups --query "logGroups[*].[logGroupName,storedBytes]" --output table'

# Shortcuts
alias logs-help='cat ~/Documents/GitHub/Secure_AWS_Infrastructure/AWS_LOGS_VIEWING_GUIDE.md | less'

echo "AWS CloudWatch Logs aliases loaded!"
echo ""
echo "Available commands:"
echo "  logs-ecs              - Tail ECS container logs"
echo "  logs-pageviews        - Tail page view logs (after analytics deployed)"
echo "  logs-engagement       - Tail engagement logs (after analytics deployed)"
echo "  logs-lambda           - Tail Lambda function logs"
echo "  logs-bookings         - Filter booking events"
echo "  logs-errors-all       - Show all errors from last 24h"
echo "  logs-list             - List all log groups"
echo "  logs-help             - Show complete guide"
echo ""
echo "Try: logs-ecs"

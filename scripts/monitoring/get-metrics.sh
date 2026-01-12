#!/bin/bash
# Get CloudWatch Metrics
# Fetches and displays metrics for the application

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Get CloudWatch Metrics

OPTIONS:
    -e, --environment      Environment (e.g., prod, staging, dev) [REQUIRED]
    -a, --app-name         Application name [REQUIRED]
    -r, --region           AWS region (default: us-east-1)
    -p, --period           Time period in minutes (default: 60)
    -h, --help             Show this help message

EXAMPLES:
    $0 -e prod -a webapp
    $0 -e staging -a api -p 120

EOF
    exit 1
}

# Defaults
ENVIRONMENT=""
APP_NAME=""
REGION="${AWS_REGION:-us-east-1}"
PERIOD=60

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--app-name)
            APP_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -p|--period)
            PERIOD="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate
if [ -z "$ENVIRONMENT" ] || [ -z "$APP_NAME" ]; then
    echo "Missing required parameters"
    usage
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}CloudWatch Metrics${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Environment: $ENVIRONMENT"
echo "Application: $APP_NAME"
echo "Region: $REGION"
echo "Period: Last $PERIOD minutes"
echo ""

CLUSTER_NAME="${ENVIRONMENT}-${APP_NAME}-cluster"
SERVICE_NAME="${ENVIRONMENT}-${APP_NAME}-service"
ALB_NAME="${ENVIRONMENT}-${APP_NAME}-alb"

START_TIME=$(date -u -v-${PERIOD}M +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -u -d "$PERIOD minutes ago" +"%Y-%m-%dT%H:%M:%S")
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S")

# ECS Metrics
echo -e "${GREEN}ECS Metrics:${NC}"
echo "----------------------------------------"

# CPU Utilization
CPU=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --dimensions Name=ClusterName,Value="$CLUSTER_NAME" Name=ServiceName,Value="$SERVICE_NAME" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Average \
    --region "$REGION" \
    --query 'Datapoints[-1].Average' \
    --output text 2>/dev/null || echo "N/A")

echo "CPU Utilization: ${CPU}%"

# Memory Utilization
MEMORY=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name MemoryUtilization \
    --dimensions Name=ClusterName,Value="$CLUSTER_NAME" Name=ServiceName,Value="$SERVICE_NAME" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Average \
    --region "$REGION" \
    --query 'Datapoints[-1].Average' \
    --output text 2>/dev/null || echo "N/A")

echo "Memory Utilization: ${MEMORY}%"

# Running Task Count
TASKS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null || echo "0")

echo "Running Tasks: $TASKS"
echo ""

# ALB Metrics
echo -e "${GREEN}ALB Metrics:${NC}"
echo "----------------------------------------"

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --region "$REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || echo "")

if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    # Extract ALB suffix for metrics
    ALB_SUFFIX=$(echo "$ALB_ARN" | cut -d: -f6 | cut -d/ -f2-)

    # Request Count
    REQUESTS=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ApplicationELB \
        --metric-name RequestCount \
        --dimensions Name=LoadBalancer,Value="$ALB_SUFFIX" \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --period 300 \
        --statistics Sum \
        --region "$REGION" \
        --query 'sum(Datapoints[*].Sum)' \
        --output text 2>/dev/null || echo "0")

    echo "Total Requests: $REQUESTS"

    # Target Response Time
    RESPONSE_TIME=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ApplicationELB \
        --metric-name TargetResponseTime \
        --dimensions Name=LoadBalancer,Value="$ALB_SUFFIX" \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --period 300 \
        --statistics Average \
        --region "$REGION" \
        --query 'Datapoints[-1].Average' \
        --output text 2>/dev/null || echo "N/A")

    echo "Avg Response Time: ${RESPONSE_TIME}s"

    # 2XX Count
    COUNT_2XX=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ApplicationELB \
        --metric-name HTTPCode_Target_2XX_Count \
        --dimensions Name=LoadBalancer,Value="$ALB_SUFFIX" \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --period 300 \
        --statistics Sum \
        --region "$REGION" \
        --query 'sum(Datapoints[*].Sum)' \
        --output text 2>/dev/null || echo "0")

    echo "2XX Responses: $COUNT_2XX"

    # 5XX Count
    COUNT_5XX=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ApplicationELB \
        --metric-name HTTPCode_Target_5XX_Count \
        --dimensions Name=LoadBalancer,Value="$ALB_SUFFIX" \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --period 300 \
        --statistics Sum \
        --region "$REGION" \
        --query 'sum(Datapoints[*].Sum)' \
        --output text 2>/dev/null || echo "0")

    echo "5XX Responses: $COUNT_5XX"

    # Error Rate
    if [ "$REQUESTS" != "0" ] && [ "$REQUESTS" != "None" ]; then
        ERROR_RATE=$(awk "BEGIN {printf \"%.2f\", ($COUNT_5XX / $REQUESTS) * 100}")
        echo "Error Rate: ${ERROR_RATE}%"
    fi
else
    echo "ALB not found"
fi

echo ""
echo -e "${YELLOW}========================================${NC}"

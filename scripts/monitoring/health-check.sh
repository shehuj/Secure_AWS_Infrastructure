#!/bin/bash
# Health Check Script
# Performs comprehensive health checks on the application

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Perform Health Checks

OPTIONS:
    -e, --environment      Environment (e.g., prod, staging, dev) [REQUIRED]
    -a, --app-name         Application name [REQUIRED]
    -r, --region           AWS region (default: us-east-1)
    -h, --help             Show this help message

EXAMPLES:
    $0 -e prod -a webapp
    $0 -e staging -a api

EOF
    exit 1
}

# Defaults
ENVIRONMENT=""
APP_NAME=""
REGION="${AWS_REGION:-us-east-1}"

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
echo -e "${BLUE}Health Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Environment: $ENVIRONMENT"
echo "Application: $APP_NAME"
echo "Region: $REGION"
echo "Time: $(date)"
echo ""

HEALTH_SCORE=0
MAX_SCORE=100

CLUSTER_NAME="${ENVIRONMENT}-${APP_NAME}-cluster"
SERVICE_NAME="${ENVIRONMENT}-${APP_NAME}-service"
ALB_NAME="${ENVIRONMENT}-${APP_NAME}-alb"

# Check 1: ECS Service Health (30 points)
echo -e "${YELLOW}[1/5] Checking ECS Service...${NC}"
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
    --output json 2>/dev/null)

if [ -n "$SERVICE_STATUS" ]; then
    STATUS=$(echo "$SERVICE_STATUS" | jq -r '.Status')
    RUNNING=$(echo "$SERVICE_STATUS" | jq -r '.Running')
    DESIRED=$(echo "$SERVICE_STATUS" | jq -r '.Desired')

    if [ "$STATUS" == "ACTIVE" ] && [ "$RUNNING" -eq "$DESIRED" ]; then
        echo -e "  ${GREEN}✓${NC} Service is healthy ($RUNNING/$DESIRED tasks)"
        HEALTH_SCORE=$((HEALTH_SCORE + 30))
    else
        echo -e "  ${RED}✗${NC} Service issues detected ($RUNNING/$DESIRED tasks)"
    fi
else
    echo -e "  ${RED}✗${NC} Service not found"
fi

# Check 2: Target Group Health (25 points)
echo -e "${YELLOW}[2/5] Checking Target Groups...${NC}"
for TG in "${ENVIRONMENT}-${APP_NAME}-blue-tg" "${ENVIRONMENT}-${APP_NAME}-green-tg"; do
    TG_ARN=$(aws elbv2 describe-target-groups \
        --names "$TG" \
        --region "$REGION" \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null || echo "")

    if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
        HEALTHY=$(aws elbv2 describe-target-health \
            --target-group-arn "$TG_ARN" \
            --region "$REGION" \
            --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
            --output text)

        TOTAL=$(aws elbv2 describe-target-health \
            --target-group-arn "$TG_ARN" \
            --region "$REGION" \
            --query 'length(TargetHealthDescriptions)' \
            --output text)

        if [ "$HEALTHY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} $TG: $HEALTHY/$TOTAL healthy"
            HEALTH_SCORE=$((HEALTH_SCORE + 12))
        elif [ "$TOTAL" -eq 0 ]; then
            echo -e "  ${YELLOW}!${NC} $TG: No targets"
        else
            echo -e "  ${RED}✗${NC} $TG: $HEALTHY/$TOTAL healthy"
        fi
    fi
done

# Check 3: ALB Health (20 points)
echo -e "${YELLOW}[3/5] Checking ALB...${NC}"
ALB_STATE=$(aws elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --region "$REGION" \
    --query 'LoadBalancers[0].{State:State.Code,DNS:DNSName}' \
    --output json 2>/dev/null)

if [ -n "$ALB_STATE" ]; then
    STATE=$(echo "$ALB_STATE" | jq -r '.State')
    DNS=$(echo "$ALB_STATE" | jq -r '.DNS')

    if [ "$STATE" == "active" ]; then
        echo -e "  ${GREEN}✓${NC} ALB is active: $DNS"
        HEALTH_SCORE=$((HEALTH_SCORE + 10))

        # Test endpoint
        if curl -f -k -s -o /dev/null "https://$DNS/" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Endpoint is responding"
            HEALTH_SCORE=$((HEALTH_SCORE + 10))
        else
            echo -e "  ${YELLOW}!${NC} Endpoint not responding"
        fi
    else
        echo -e "  ${RED}✗${NC} ALB state: $STATE"
    fi
else
    echo -e "  ${RED}✗${NC} ALB not found"
fi

# Check 4: Recent Deployments (15 points)
echo -e "${YELLOW}[4/5] Checking Recent Deployments...${NC}"
CODEDEPLOY_APP="${ENVIRONMENT}-${APP_NAME}"
DEPLOYMENT_GROUP="${ENVIRONMENT}-${APP_NAME}-dg"

RECENT_DEPLOYMENTS=$(aws deploy list-deployments \
    --application-name "$CODEDEPLOY_APP" \
    --deployment-group-name "$DEPLOYMENT_GROUP" \
    --region "$REGION" \
    --max-items 1 \
    --query 'deployments' \
    --output text 2>/dev/null || echo "")

if [ -n "$RECENT_DEPLOYMENTS" ]; then
    DEPLOYMENT_STATUS=$(aws deploy get-deployment \
        --deployment-id "$RECENT_DEPLOYMENTS" \
        --region "$REGION" \
        --query 'deploymentInfo.status' \
        --output text 2>/dev/null)

    if [ "$DEPLOYMENT_STATUS" == "Succeeded" ]; then
        echo -e "  ${GREEN}✓${NC} Last deployment: Succeeded"
        HEALTH_SCORE=$((HEALTH_SCORE + 15))
    elif [ "$DEPLOYMENT_STATUS" == "InProgress" ]; then
        echo -e "  ${YELLOW}!${NC} Deployment in progress"
        HEALTH_SCORE=$((HEALTH_SCORE + 10))
    else
        echo -e "  ${RED}✗${NC} Last deployment: $DEPLOYMENT_STATUS"
    fi
else
    echo -e "  ${YELLOW}!${NC} No deployments found"
    HEALTH_SCORE=$((HEALTH_SCORE + 10))
fi

# Check 5: CloudWatch Alarms (10 points)
echo -e "${YELLOW}[5/5] Checking CloudWatch Alarms...${NC}"
ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "$ENVIRONMENT-$APP_NAME" \
    --region "$REGION" \
    --query 'MetricAlarms[?StateValue==`ALARM`]' \
    --output json 2>/dev/null)

ALARM_COUNT=$(echo "$ALARMS" | jq -r 'length')

if [ "$ALARM_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} No active alarms"
    HEALTH_SCORE=$((HEALTH_SCORE + 10))
else
    echo -e "  ${RED}✗${NC} $ALARM_COUNT alarm(s) active"
    echo "$ALARMS" | jq -r '.[] | "    - \(.AlarmName): \(.StateReason)"'
fi

# Health Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Health Score: $HEALTH_SCORE/$MAX_SCORE${NC}"
echo -e "${BLUE}========================================${NC}"

if [ $HEALTH_SCORE -ge 90 ]; then
    echo -e "${GREEN}Status: HEALTHY ✓${NC}"
    exit 0
elif [ $HEALTH_SCORE -ge 70 ]; then
    echo -e "${YELLOW}Status: DEGRADED !${NC}"
    exit 1
else
    echo -e "${RED}Status: UNHEALTHY ✗${NC}"
    exit 2
fi

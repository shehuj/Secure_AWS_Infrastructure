#!/bin/bash
# Integration Tests
# Tests infrastructure integration and connectivity

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

ENV="${1:-dev}"
REGION="${AWS_REGION:-us-east-1}"

log_info "Running integration tests for environment: $ENV"

ERRORS=0

# Test 1: AWS Connectivity
log_info "Testing AWS connectivity..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
    log_success "AWS connectivity OK (Account: $ACCOUNT)"
else
    log_error "Cannot connect to AWS"
    ERRORS=$((ERRORS + 1))
fi

# Test 2: Check ECS Cluster
log_info "Checking ECS cluster..."
CLUSTER_NAME="${ENV}-webapp-cluster"

if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$REGION" --query 'clusters[0].status' --output text | grep -q "ACTIVE"; then
    log_success "ECS cluster $CLUSTER_NAME is active"
else
    log_warning "ECS cluster $CLUSTER_NAME not found or not active"
fi

# Test 3: Check ALB
log_info "Checking Application Load Balancer..."
ALB_NAME="${ENV}-webapp-alb"

if ALB_DNS=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$REGION" --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null); then
    log_success "ALB $ALB_NAME found: $ALB_DNS"

    # Test ALB endpoint
    log_info "Testing ALB endpoint..."
    if curl -f -k "https://$ALB_DNS/" > /dev/null 2>&1; then
        log_success "ALB endpoint is responding"
    else
        log_warning "ALB endpoint not responding (may be expected if not deployed)"
    fi
else
    log_warning "ALB $ALB_NAME not found"
fi

# Test 4: Check Target Groups
log_info "Checking target groups..."
for TG in "${ENV}-webapp-blue-tg" "${ENV}-webapp-green-tg"; do
    if TG_ARN=$(aws elbv2 describe-target-groups --names "$TG" --region "$REGION" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null); then
        HEALTHY=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region "$REGION" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)
        TOTAL=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region "$REGION" --query 'length(TargetHealthDescriptions)' --output text)

        if [ "$HEALTHY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
            log_success "$TG: $HEALTHY/$TOTAL targets healthy"
        else
            log_warning "$TG: $HEALTHY/$TOTAL targets healthy"
        fi
    else
        log_warning "Target group $TG not found"
    fi
done

# Test 5: Check CodeDeploy Application
log_info "Checking CodeDeploy application..."
CODEDEPLOY_APP="${ENV}-webapp"

if aws deploy get-application --application-name "$CODEDEPLOY_APP" --region "$REGION" > /dev/null 2>&1; then
    log_success "CodeDeploy application $CODEDEPLOY_APP exists"
else
    log_warning "CodeDeploy application $CODEDEPLOY_APP not found"
fi

# Test 6: Check CloudWatch Log Group
log_info "Checking CloudWatch log group..."
LOG_GROUP="/ecs/$ENV/webapp"

if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$REGION" --query 'logGroups[0].logGroupName' --output text | grep -q "$LOG_GROUP"; then
    log_success "CloudWatch log group $LOG_GROUP exists"
else
    log_warning "CloudWatch log group $LOG_GROUP not found"
fi

# Test 7: Check Security Groups
log_info "Checking security groups..."
SG_NAMES=("${ENV}-webapp-alb-sg" "${ENV}-webapp-ecs-sg")

for SG_NAME in "${SG_NAMES[@]}"; do
    if SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" --region "$REGION" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null); then
        if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
            log_success "Security group $SG_NAME exists: $SG_ID"
        else
            log_warning "Security group $SG_NAME not found"
        fi
    else
        log_warning "Security group $SG_NAME not found"
    fi
done

# Test 8: Check IAM Roles
log_info "Checking IAM roles..."
IAM_ROLES=(
    "${ENV}-webapp-ecs-task-execution-role"
    "${ENV}-webapp-ecs-task-role"
    "${ENV}-webapp-codedeploy-role"
)

for ROLE in "${IAM_ROLES[@]}"; do
    if aws iam get-role --role-name "$ROLE" > /dev/null 2>&1; then
        log_success "IAM role $ROLE exists"
    else
        log_warning "IAM role $ROLE not found"
    fi
done

# Summary
echo ""
echo "========================================"
echo "Integration Test Summary"
echo "========================================"

if [ $ERRORS -eq 0 ]; then
    log_success "All critical tests passed!"
    exit 0
else
    log_error "Found $ERRORS critical error(s)"
    exit 1
fi

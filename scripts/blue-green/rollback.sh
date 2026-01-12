#!/bin/bash
# Rollback Script for Blue-Green Deployments
# This script stops a deployment and optionally rolls back to previous version

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Rollback Blue-Green Deployment

OPTIONS:
    -e, --environment      Environment (e.g., prod, staging, dev) [REQUIRED]
    -a, --app-name         Application name [REQUIRED]
    -d, --deployment-id    Deployment ID to stop/rollback (optional)
    -r, --region           AWS region (default: us-east-1)
    -s, --stop-only        Only stop deployment, don't rollback
    -h, --help             Show this help message

EXAMPLES:
    # Stop current deployment and rollback
    $0 -e prod -a webapp

    # Stop specific deployment
    $0 -e prod -a webapp -d d-XXXXX

    # Just stop, don't rollback
    $0 -e prod -a webapp --stop-only

EOF
    exit 1
}

# Defaults
ENVIRONMENT=""
APP_NAME=""
DEPLOYMENT_ID=""
REGION="${AWS_REGION:-us-east-1}"
STOP_ONLY=false

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
        -d|--deployment-id)
            DEPLOYMENT_ID="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -s|--stop-only)
            STOP_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate
if [ -z "$ENVIRONMENT" ] || [ -z "$APP_NAME" ]; then
    log_error "Missing required parameters"
    usage
fi

log_info "=========================================="
log_info "Blue-Green Deployment Rollback"
log_info "=========================================="
log_info "Environment: $ENVIRONMENT"
log_info "Application: $APP_NAME"
log_info "Region: $REGION"
log_info ""

CODEDEPLOY_APP="${ENVIRONMENT}-${APP_NAME}"
DEPLOYMENT_GROUP="${ENVIRONMENT}-${APP_NAME}-dg"

# If no deployment ID provided, get the latest
if [ -z "$DEPLOYMENT_ID" ]; then
    log_info "Finding latest deployment..."
    DEPLOYMENT_ID=$(aws deploy list-deployments \
        --application-name "$CODEDEPLOY_APP" \
        --deployment-group-name "$DEPLOYMENT_GROUP" \
        --region "$REGION" \
        --max-items 1 \
        --query 'deployments[0]' \
        --output text)

    if [ -z "$DEPLOYMENT_ID" ] || [ "$DEPLOYMENT_ID" = "None" ]; then
        log_error "No deployments found"
        exit 1
    fi
    log_info "Latest deployment: $DEPLOYMENT_ID"
fi

# Get deployment status
log_info "Checking deployment status..."
DEPLOYMENT_STATUS=$(aws deploy get-deployment \
    --deployment-id "$DEPLOYMENT_ID" \
    --region "$REGION" \
    --query 'deploymentInfo.status' \
    --output text)

log_info "Current status: $DEPLOYMENT_STATUS"

# Stop deployment if in progress
if [ "$DEPLOYMENT_STATUS" = "InProgress" ] || [ "$DEPLOYMENT_STATUS" = "Ready" ]; then
    log_warning "Stopping deployment $DEPLOYMENT_ID..."

    aws deploy stop-deployment \
        --deployment-id "$DEPLOYMENT_ID" \
        --region "$REGION" \
        --auto-rollback-enabled || {
        log_error "Failed to stop deployment"
        exit 1
    }

    log_success "Deployment stopped"
    log_info "Auto-rollback initiated by CodeDeploy"
else
    log_info "Deployment is not in progress (status: $DEPLOYMENT_STATUS)"
fi

# Manual rollback if requested
if [ "$STOP_ONLY" = false ]; then
    log_info ""
    log_info "Initiating manual rollback..."

    # Get previous successful deployment
    PREVIOUS_DEPLOYMENT=$(aws deploy list-deployments \
        --application-name "$CODEDEPLOY_APP" \
        --deployment-group-name "$DEPLOYMENT_GROUP" \
        --region "$REGION" \
        --include-only-statuses Succeeded \
        --max-items 1 \
        --query 'deployments[0]' \
        --output text)

    if [ -z "$PREVIOUS_DEPLOYMENT" ] || [ "$PREVIOUS_DEPLOYMENT" = "None" ]; then
        log_warning "No previous successful deployment found"
        log_info "Cannot perform manual rollback"
    else
        log_info "Previous successful deployment: $PREVIOUS_DEPLOYMENT"

        # Get task definition from previous deployment
        PREVIOUS_TASK_DEF=$(aws deploy get-deployment \
            --deployment-id "$PREVIOUS_DEPLOYMENT" \
            --region "$REGION" \
            --query 'deploymentInfo.revision.appSpecContent.content' \
            --output text | \
            jq -r '.Resources[0].TargetService.Properties.TaskDefinition')

        if [ -n "$PREVIOUS_TASK_DEF" ]; then
            log_info "Rolling back to task definition: $PREVIOUS_TASK_DEF"

            # Create AppSpec for rollback
            ROLLBACK_APPSPEC="/tmp/rollback-appspec.json"
            cat > "$ROLLBACK_APPSPEC" <<EOF
{
  "version": 0.0,
  "Resources": [
    {
      "TargetService": {
        "Type": "AWS::ECS::Service",
        "Properties": {
          "TaskDefinition": "$PREVIOUS_TASK_DEF",
          "LoadBalancerInfo": {
            "ContainerName": "$APP_NAME",
            "ContainerPort": 80
          }
        }
      }
    }
  ]
}
EOF

            # Trigger rollback deployment
            ROLLBACK_ID=$(aws deploy create-deployment \
                --application-name "$CODEDEPLOY_APP" \
                --deployment-group-name "$DEPLOYMENT_GROUP" \
                --revision "revisionType=AppSpecContent,appSpecContent={content='$(cat $ROLLBACK_APPSPEC | jq -c .)'}" \
                --region "$REGION" \
                --description "Rollback from deployment $DEPLOYMENT_ID" \
                --query 'deploymentId' \
                --output text)

            rm -f "$ROLLBACK_APPSPEC"

            if [ -n "$ROLLBACK_ID" ]; then
                log_success "Rollback deployment created: $ROLLBACK_ID"

                ROLLBACK_URL="https://${REGION}.console.aws.amazon.com/codesuite/codedeploy/deployments/${ROLLBACK_ID}?region=${REGION}"
                log_info "Monitor rollback: $ROLLBACK_URL"
            else
                log_error "Failed to create rollback deployment"
            fi
        fi
    fi
fi

log_info ""
log_success "=========================================="
log_success "Rollback process completed!"
log_success "=========================================="

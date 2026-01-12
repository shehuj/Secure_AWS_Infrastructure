#!/bin/bash
# Blue-Green Deployment Script for ECS
# This script triggers a blue-green deployment using AWS CodeDeploy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to print colored messages
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

# Function to show usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Blue-Green Deployment Script for ECS

OPTIONS:
    -e, --environment      Environment (e.g., prod, staging, dev) [REQUIRED]
    -a, --app-name         Application name [REQUIRED]
    -i, --image            Docker image URI [REQUIRED]
    -r, --region           AWS region (default: us-east-1)
    -w, --wait             Wait for deployment to complete (default: false)
    -n, --no-wait          Don't wait for deployment completion
    -h, --help             Show this help message

EXAMPLES:
    # Deploy new image
    $0 -e prod -a webapp -i nginx:latest

    # Deploy and wait for completion
    $0 -e prod -a webapp -i nginx:latest -w

    # Deploy to specific region
    $0 -e staging -a api -i myapp:v2.0 -r us-west-2

ENVIRONMENT VARIABLES:
    AWS_REGION             AWS region (can be set instead of -r flag)
    AWS_PROFILE            AWS profile to use

EOF
    exit 1
}

# Default values
ENVIRONMENT=""
APP_NAME=""
IMAGE=""
REGION="${AWS_REGION:-us-east-1}"
WAIT_FOR_DEPLOYMENT=false

# Parse command line arguments
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
        -i|--image)
            IMAGE="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_FOR_DEPLOYMENT=true
            shift
            ;;
        -n|--no-wait)
            WAIT_FOR_DEPLOYMENT=false
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

# Validate required parameters
if [ -z "$ENVIRONMENT" ] || [ -z "$APP_NAME" ] || [ -z "$IMAGE" ]; then
    log_error "Missing required parameters"
    usage
fi

log_info "=========================================="
log_info "Blue-Green Deployment"
log_info "=========================================="
log_info "Environment: $ENVIRONMENT"
log_info "Application: $APP_NAME"
log_info "Image: $IMAGE"
log_info "Region: $REGION"
log_info ""

# Define names
CLUSTER_NAME="${ENVIRONMENT}-${APP_NAME}-cluster"
SERVICE_NAME="${ENVIRONMENT}-${APP_NAME}-service"
TASK_FAMILY="${ENVIRONMENT}-${APP_NAME}"
CODEDEPLOY_APP="${ENVIRONMENT}-${APP_NAME}"
DEPLOYMENT_GROUP="${ENVIRONMENT}-${APP_NAME}-dg"

# Check AWS CLI is installed
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed"
    exit 1
fi

# Check if cluster exists
log_info "Checking if ECS cluster exists..."
if ! aws ecs describe-clusters \
    --clusters "$CLUSTER_NAME" \
    --region "$REGION" \
    --query 'clusters[0].clusterName' \
    --output text 2>/dev/null | grep -q "$CLUSTER_NAME"; then
    log_error "ECS cluster '$CLUSTER_NAME' not found in region $REGION"
    exit 1
fi
log_success "Cluster found: $CLUSTER_NAME"

# Get current task definition
log_info "Retrieving current task definition..."
TASK_DEF=$(aws ecs describe-task-definition \
    --task-definition "$TASK_FAMILY" \
    --region "$REGION" \
    --query 'taskDefinition' \
    --output json)

if [ -z "$TASK_DEF" ] || [ "$TASK_DEF" = "null" ]; then
    log_error "Failed to retrieve task definition for $TASK_FAMILY"
    exit 1
fi

# Update the image in the task definition
log_info "Creating new task definition with image: $IMAGE"
NEW_TASK_DEF=$(echo "$TASK_DEF" | jq --arg IMAGE "$IMAGE" \
    'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy) |
    .containerDefinitions[0].image = $IMAGE')

# Register new task definition
log_info "Registering new task definition..."
NEW_TASK_ARN=$(echo "$NEW_TASK_DEF" | \
    aws ecs register-task-definition \
    --cli-input-json file:///dev/stdin \
    --region "$REGION" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

if [ -z "$NEW_TASK_ARN" ]; then
    log_error "Failed to register new task definition"
    exit 1
fi
log_success "New task definition registered: $NEW_TASK_ARN"

# Get task definition revision
REVISION=$(echo "$NEW_TASK_ARN" | awk -F: '{print $NF}')
log_info "Task definition revision: $REVISION"

# Create AppSpec file
log_info "Creating AppSpec file..."
APPSPEC_FILE="/tmp/appspec-${ENVIRONMENT}-${APP_NAME}.json"

cat > "$APPSPEC_FILE" <<EOF
{
  "version": 0.0,
  "Resources": [
    {
      "TargetService": {
        "Type": "AWS::ECS::Service",
        "Properties": {
          "TaskDefinition": "$NEW_TASK_ARN",
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

log_success "AppSpec file created: $APPSPEC_FILE"

# Trigger CodeDeploy deployment
log_info "Triggering CodeDeploy deployment..."
DEPLOYMENT_ID=$(aws deploy create-deployment \
    --application-name "$CODEDEPLOY_APP" \
    --deployment-group-name "$DEPLOYMENT_GROUP" \
    --revision "revisionType=AppSpecContent,appSpecContent={content='$(cat $APPSPEC_FILE | jq -c .)'},appSpecContent={sha256='$(sha256sum $APPSPEC_FILE | awk '{print $1}')'}" \
    --region "$REGION" \
    --query 'deploymentId' \
    --output text 2>/dev/null)

if [ -z "$DEPLOYMENT_ID" ] || [ "$DEPLOYMENT_ID" = "None" ]; then
    log_error "Failed to trigger CodeDeploy deployment"
    exit 1
fi

log_success "Deployment triggered successfully!"
log_info "Deployment ID: $DEPLOYMENT_ID"

# Get deployment console URL
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DEPLOYMENT_URL="https://${REGION}.console.aws.amazon.com/codesuite/codedeploy/deployments/${DEPLOYMENT_ID}?region=${REGION}"
log_info "Monitor deployment: $DEPLOYMENT_URL"

# Wait for deployment if requested
if [ "$WAIT_FOR_DEPLOYMENT" = true ]; then
    log_info ""
    log_info "Waiting for deployment to complete..."
    log_info "This may take several minutes..."
    log_info ""

    aws deploy wait deployment-successful \
        --deployment-id "$DEPLOYMENT_ID" \
        --region "$REGION" \
        2>/dev/null && {
        log_success "Deployment completed successfully!"

        # Get final status
        FINAL_STATUS=$(aws deploy get-deployment \
            --deployment-id "$DEPLOYMENT_ID" \
            --region "$REGION" \
            --query 'deploymentInfo.status' \
            --output text)

        log_info "Final status: $FINAL_STATUS"
    } || {
        log_error "Deployment failed or timed out"

        # Get failure information
        FAILURE_INFO=$(aws deploy get-deployment \
            --deployment-id "$DEPLOYMENT_ID" \
            --region "$REGION" \
            --query 'deploymentInfo.{Status:status,ErrorInfo:errorInformation}' \
            --output json)

        log_error "Failure details: $FAILURE_INFO"
        exit 1
    }
else
    log_info ""
    log_info "Deployment triggered. Use the following command to check status:"
    log_info "aws deploy get-deployment --deployment-id $DEPLOYMENT_ID --region $REGION"
    log_info ""
    log_info "Or wait for completion:"
    log_info "$0 -e $ENVIRONMENT -a $APP_NAME -i $IMAGE -w"
fi

# Clean up
rm -f "$APPSPEC_FILE"

log_info ""
log_success "=========================================="
log_success "Deployment process completed!"
log_success "=========================================="

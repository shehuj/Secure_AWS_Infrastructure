#!/bin/bash
# Check status of blue-green deployments

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_header() {
    echo -e "${CYAN}$1${NC}"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Check Blue-Green Deployment Status

OPTIONS:
    -e, --environment      Environment (e.g., prod, staging, dev) [REQUIRED]
    -a, --app-name         Application name [REQUIRED]
    -d, --deployment-id    Check specific deployment ID
    -r, --region           AWS region (default: us-east-1)
    -w, --watch            Watch mode - refresh every 10 seconds
    -h, --help             Show this help message

EXAMPLES:
    # Check current status
    $0 -e prod -a webapp

    # Watch deployment progress
    $0 -e prod -a webapp --watch

    # Check specific deployment
    $0 -e prod -a webapp -d d-XXXXX

EOF
    exit 1
}

# Defaults
ENVIRONMENT=""
APP_NAME=""
DEPLOYMENT_ID=""
REGION="${AWS_REGION:-us-east-1}"
WATCH_MODE=false

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
        -w|--watch)
            WATCH_MODE=true
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

show_status() {
    clear

    log_header "=========================================="
    log_header " Blue-Green Deployment Status"
    log_header "=========================================="
    log_info "Environment: $ENVIRONMENT"
    log_info "Application: $APP_NAME"
    log_info "Region: $REGION"
    log_info "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    CLUSTER_NAME="${ENVIRONMENT}-${APP_NAME}-cluster"
    SERVICE_NAME="${ENVIRONMENT}-${APP_NAME}-service"
    CODEDEPLOY_APP="${ENVIRONMENT}-${APP_NAME}"
    DEPLOYMENT_GROUP="${ENVIRONMENT}-${APP_NAME}-dg"

    # ECS Service Status
    log_header "ECS Service Status"
    log_header "------------------------------------------"

    ECS_STATUS=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$REGION" \
        --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}' \
        --output json 2>/dev/null)

    if [ -n "$ECS_STATUS" ]; then
        echo "$ECS_STATUS" | jq -r 'to_entries | .[] | "  \(.key): \(.value)"'
    else
        log_error "Failed to retrieve service status"
    fi
    echo ""

    # Target Group Health
    log_header "Target Groups Health"
    log_header "------------------------------------------"

    BLUE_TG="${ENVIRONMENT}-${APP_NAME}-blue-tg"
    GREEN_TG="${ENVIRONMENT}-${APP_NAME}-green-tg"

    for TG in "$BLUE_TG" "$GREEN_TG"; do
        COLOR=$(echo $TG | grep -o '\(blue\|green\)' | tr '[:lower:]' '[:upper:]')

        TARGET_HEALTH=$(aws elbv2 describe-target-health \
            --target-group-arn $(aws elbv2 describe-target-groups \
                --names "$TG" \
                --region "$REGION" \
                --query 'TargetGroups[0].TargetGroupArn' \
                --output text 2>/dev/null) \
            --region "$REGION" \
            --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
            --output text 2>/dev/null || echo "0")

        TOTAL_TARGETS=$(aws elbv2 describe-target-health \
            --target-group-arn $(aws elbv2 describe-target-groups \
                --names "$TG" \
                --region "$REGION" \
                --query 'TargetGroups[0].TargetGroupArn' \
                --output text 2>/dev/null) \
            --region "$REGION" \
            --query 'length(TargetHealthDescriptions)' \
            --output text 2>/dev/null || echo "0")

        if [ "$TARGET_HEALTH" -eq "$TOTAL_TARGETS" ] && [ "$TOTAL_TARGETS" -gt 0 ]; then
            log_success "$COLOR: $TARGET_HEALTH/$TOTAL_TARGETS healthy"
        elif [ "$TOTAL_TARGETS" -eq 0 ]; then
            echo -e "  ${CYAN}$COLOR${NC}: No targets"
        else
            log_warning "$COLOR: $TARGET_HEALTH/$TOTAL_TARGETS healthy"
        fi
    done
    echo ""

    # Deployment Status
    log_header "Recent Deployments"
    log_header "------------------------------------------"

    if [ -n "$DEPLOYMENT_ID" ]; then
        DEPLOYMENTS="$DEPLOYMENT_ID"
    else
        DEPLOYMENTS=$(aws deploy list-deployments \
            --application-name "$CODEDEPLOY_APP" \
            --deployment-group-name "$DEPLOYMENT_GROUP" \
            --region "$REGION" \
            --max-items 5 \
            --query 'deployments' \
            --output text 2>/dev/null)
    fi

    if [ -n "$DEPLOYMENTS" ]; then
        for DEP_ID in $DEPLOYMENTS; do
            DEP_INFO=$(aws deploy get-deployment \
                --deployment-id "$DEP_ID" \
                --region "$REGION" \
                --query 'deploymentInfo.{ID:deploymentId,Status:status,Created:createTime,Desc:description}' \
                --output json 2>/dev/null)

            if [ -n "$DEP_INFO" ]; then
                STATUS=$(echo "$DEP_INFO" | jq -r '.Status')
                CREATED=$(echo "$DEP_INFO" | jq -r '.Created')
                DESC=$(echo "$DEP_INFO" | jq -r '.Desc // "No description"')

                case $STATUS in
                    Succeeded)
                        STATUS_ICON="${GREEN}✓${NC}"
                        ;;
                    Failed)
                        STATUS_ICON="${RED}✗${NC}"
                        ;;
                    InProgress)
                        STATUS_ICON="${YELLOW}⟳${NC}"
                        ;;
                    *)
                        STATUS_ICON="${CYAN}•${NC}"
                        ;;
                esac

                echo -e "  $STATUS_ICON ${DEP_ID:0:12}... - $STATUS"
                echo -e "     Created: $CREATED"
                if [ "$DESC" != "No description" ]; then
                    echo -e "     $DESC"
                fi
                echo ""
            fi
        done
    else
        log_info "No recent deployments found"
    fi

    # Current Deployment Details (if in progress)
    CURRENT_DEP=$(aws deploy list-deployments \
        --application-name "$CODEDEPLOY_APP" \
        --deployment-group-name "$DEPLOYMENT_GROUP" \
        --region "$REGION" \
        --include-only-statuses InProgress \
        --max-items 1 \
        --query 'deployments[0]' \
        --output text 2>/dev/null)

    if [ -n "$CURRENT_DEP" ] && [ "$CURRENT_DEP" != "None" ]; then
        echo ""
        log_header "Active Deployment Progress"
        log_header "------------------------------------------"

        DEP_DETAILS=$(aws deploy get-deployment \
            --deployment-id "$CURRENT_DEP" \
            --region "$REGION" \
            --query 'deploymentInfo.deploymentOverview' \
            --output json 2>/dev/null)

        if [ -n "$DEP_DETAILS" ]; then
            echo "$DEP_DETAILS" | jq -r 'to_entries | .[] | "  \(.key): \(.value)"'
        fi

        echo ""
        CONSOLE_URL="https://${REGION}.console.aws.amazon.com/codesuite/codedeploy/deployments/${CURRENT_DEP}?region=${REGION}"
        log_info "Monitor in console: $CONSOLE_URL"
    fi

    if [ "$WATCH_MODE" = true ]; then
        echo ""
        log_info "Refreshing in 10 seconds... (Ctrl+C to exit)"
    fi
}

# Main loop
if [ "$WATCH_MODE" = true ]; then
    while true; do
        show_status
        sleep 10
    done
else
    show_status
fi

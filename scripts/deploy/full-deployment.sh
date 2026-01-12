#!/bin/bash
# Full Deployment Orchestration
# Orchestrates complete end-to-end deployment

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

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Full Deployment Orchestration

OPTIONS:
    -e, --environment      Environment (dev, staging, prod) [REQUIRED]
    -i, --image            Docker image for application
    -s, --skip-tests       Skip tests (not recommended)
    -y, --yes              Auto-approve all prompts
    -h, --help             Show this help message

EXAMPLES:
    $0 -e dev
    $0 -e prod -i webapp:v2.0 -y

EOF
    exit 1
}

# Defaults
ENVIRONMENT=""
IMAGE=""
SKIP_TESTS=false
AUTO_APPROVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE="$2"
            shift 2
            ;;
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -y|--yes)
            AUTO_APPROVE=true
            shift
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
if [ -z "$ENVIRONMENT" ]; then
    log_error "Environment is required"
    usage
fi

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    log_error "Invalid environment. Must be dev, staging, or prod"
    exit 1
fi

log_header "Full Deployment to $ENVIRONMENT"

START_TIME=$(date +%s)

# Step 1: Pre-flight Checks
log_header "Step 1: Pre-flight Checks"

log_info "Checking required tools..."
REQUIRED_TOOLS=("terraform" "ansible" "aws" "jq")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        log_error "$tool is not installed"
        exit 1
    fi
    log_success "$tool is available"
done

log_info "Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    log_error "AWS credentials not configured"
    exit 1
fi
ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
log_success "AWS credentials valid (Account: $ACCOUNT)"

# Step 2: Validation
if [ "$SKIP_TESTS" == "false" ]; then
    log_header "Step 2: Validation & Testing"

    log_info "Running validation..."
    if make validate; then
        log_success "Validation passed"
    else
        log_error "Validation failed"
        exit 1
    fi

    log_info "Running tests..."
    if make test; then
        log_success "Tests passed"
    else
        log_error "Tests failed"
        exit 1
    fi

    log_info "Running security scans..."
    if make security; then
        log_success "Security scans passed"
    else
        log_warning "Security scans found issues (review before proceeding)"
        if [ "$AUTO_APPROVE" == "false" ]; then
            read -p "Continue anyway? (yes/no): " -r
            if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
                exit 1
            fi
        fi
    fi
else
    log_warning "Skipping tests (not recommended for production)"
fi

# Step 3: Terraform Infrastructure
log_header "Step 3: Terraform Infrastructure"

log_info "Initializing Terraform..."
if make tf-init; then
    log_success "Terraform initialized"
else
    log_error "Terraform initialization failed"
    exit 1
fi

log_info "Planning Terraform changes..."
if make tf-plan ENV="$ENVIRONMENT"; then
    log_success "Terraform plan complete"
else
    log_error "Terraform plan failed"
    exit 1
fi

if [ "$AUTO_APPROVE" == "false" ]; then
    echo ""
    log_warning "Review the Terraform plan above"
    read -p "Apply these changes? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
fi

log_info "Applying Terraform changes..."
if make tf-apply ENV="$ENVIRONMENT"; then
    log_success "Terraform apply complete"
else
    log_error "Terraform apply failed"
    exit 1
fi

# Wait for infrastructure to stabilize
log_info "Waiting for infrastructure to stabilize..."
sleep 30

# Step 4: Ansible Configuration
log_header "Step 4: Ansible Configuration"

log_info "Running Ansible deployment..."
if make ansible-deploy ENV="$ENVIRONMENT"; then
    log_success "Ansible deployment complete"
else
    log_error "Ansible deployment failed"
    exit 1
fi

# Step 5: Application Deployment (if image provided)
if [ -n "$IMAGE" ]; then
    log_header "Step 5: Application Deployment"

    log_info "Deploying application image: $IMAGE"
    if make deploy-wait ENV="$ENVIRONMENT" IMAGE="$IMAGE" APP=webapp; then
        log_success "Application deployment complete"
    else
        log_error "Application deployment failed"

        if [ "$AUTO_APPROVE" == "false" ]; then
            read -p "Rollback deployment? (yes/no): " -r
            if [[ $REPLY =~ ^[Yy]es$ ]]; then
                log_info "Rolling back..."
                make rollback ENV="$ENVIRONMENT" APP=webapp
            fi
        fi
        exit 1
    fi
fi

# Step 6: Integration Tests
log_header "Step 6: Integration Tests"

log_info "Running integration tests..."
if ./scripts/test/integration-test.sh "$ENVIRONMENT"; then
    log_success "Integration tests passed"
else
    log_warning "Integration tests failed or incomplete"
fi

# Step 7: Health Check
log_header "Step 7: Health Check"

log_info "Performing health check..."
if ./scripts/monitoring/health-check.sh -e "$ENVIRONMENT" -a webapp; then
    log_success "Health check passed"
else
    log_warning "Health check found issues"
fi

# Summary
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

log_header "Deployment Complete"

echo ""
log_success "Deployment to $ENVIRONMENT completed successfully!"
echo ""
echo "Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Duration: ${MINUTES}m ${SECONDS}s"
[ -n "$IMAGE" ] && echo "  Image: $IMAGE"
echo ""
echo "Next steps:"
echo "  1. Monitor deployment: make watch ENV=$ENVIRONMENT APP=webapp"
echo "  2. Check logs: make logs ENV=$ENVIRONMENT APP=webapp"
echo "  3. View metrics: ./scripts/monitoring/get-metrics.sh -e $ENVIRONMENT -a webapp"
echo ""

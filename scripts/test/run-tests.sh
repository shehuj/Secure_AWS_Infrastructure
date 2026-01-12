#!/bin/bash
# Automated Test Runner
# Runs all tests for infrastructure validation

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

log_header() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

ERRORS=0

log_header "Running Infrastructure Tests"

# Test 1: Terraform Validation
log_info "Running Terraform validation..."
if cd terraform && terraform init -backend=false > /dev/null 2>&1 && terraform validate; then
    log_success "Terraform validation passed"
else
    log_error "Terraform validation failed"
    ERRORS=$((ERRORS + 1))
fi
cd ..

# Test 2: Terraform Format Check
log_info "Checking Terraform formatting..."
if cd terraform && terraform fmt -check -recursive; then
    log_success "Terraform formatting check passed"
else
    log_error "Terraform files need formatting (run: terraform fmt -recursive)"
    ERRORS=$((ERRORS + 1))
fi
cd ..

# Test 3: Ansible Syntax Check
log_info "Running Ansible syntax check..."
if cd ansible && ansible-playbook playbooks/webserver.yml --syntax-check > /dev/null 2>&1; then
    log_success "Ansible syntax check passed"
else
    log_error "Ansible syntax check failed"
    ERRORS=$((ERRORS + 1))
fi
cd ..

# Test 4: Ansible Lint
log_info "Running Ansible lint..."
if cd ansible && ansible-lint playbooks/*.yml --profile production; then
    log_success "Ansible lint passed"
else
    log_error "Ansible lint failed"
    ERRORS=$((ERRORS + 1))
fi
cd ..

# Test 5: Shell Script Validation
log_info "Running ShellCheck..."
SHELL_ERRORS=0
find scripts -name "*.sh" -type f | while read -r script; do
    if shellcheck "$script" 2>/dev/null; then
        echo "  ✓ $script"
    else
        echo "  ✗ $script"
        SHELL_ERRORS=$((SHELL_ERRORS + 1))
    fi
done

if [ $SHELL_ERRORS -eq 0 ]; then
    log_success "ShellCheck passed"
else
    log_error "ShellCheck found issues"
    ERRORS=$((ERRORS + 1))
fi

# Test 6: YAML Lint
if command -v yamllint > /dev/null 2>&1; then
    log_info "Running yamllint..."
    if yamllint -c .yamllint ansible/; then
        log_success "YAML lint passed"
    else
        log_error "YAML lint failed"
        ERRORS=$((ERRORS + 1))
    fi
else
    log_info "yamllint not installed, skipping"
fi

# Test 7: Security - Secrets Detection
log_info "Scanning for secrets..."
if command -v detect-secrets > /dev/null 2>&1; then
    if detect-secrets scan --baseline .secrets.baseline > /dev/null 2>&1; then
        log_success "No secrets detected"
    else
        log_error "Potential secrets detected"
        ERRORS=$((ERRORS + 1))
    fi
else
    log_info "detect-secrets not installed, skipping"
fi

# Test 8: Check for Required Files
log_info "Checking for required files..."
REQUIRED_FILES=(
    "README.md"
    "terraform/main.tf"
    "ansible/playbooks/webserver.yml"
    ".gitignore"
    "Makefile"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Test 9: Validate Blue-Green Scripts
log_info "Validating blue-green deployment scripts..."
BG_SCRIPTS=(
    "scripts/blue-green/deploy.sh"
    "scripts/blue-green/rollback.sh"
    "scripts/blue-green/status.sh"
)

for script in "${BG_SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo "  ✓ $script"
    else
        echo "  ✗ $script missing or not executable"
        ERRORS=$((ERRORS + 1))
    fi
done

# Summary
echo ""
log_header "Test Summary"

if [ $ERRORS -eq 0 ]; then
    log_success "All tests passed!"
    exit 0
else
    log_error "Found $ERRORS error(s)"
    exit 1
fi

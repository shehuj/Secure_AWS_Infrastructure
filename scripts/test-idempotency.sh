#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Test Terraform idempotency
test_terraform_idempotency() {
    print_header "Testing Terraform Idempotency"

    cd terraform || exit 1

    # First plan
    print_info "Running first terraform plan..."
    terraform plan -out=tfplan1 -detailed-exitcode > /dev/null 2>&1
    FIRST_EXIT_CODE=$?

    # Second plan (should show no changes)
    print_info "Running second terraform plan..."
    terraform plan -out=tfplan2 -detailed-exitcode > /dev/null 2>&1
    SECOND_EXIT_CODE=$?

    if [ $FIRST_EXIT_CODE -eq 0 ] && [ $SECOND_EXIT_CODE -eq 0 ]; then
        print_success "Terraform is idempotent - no changes detected on re-run"
    elif [ $FIRST_EXIT_CODE -eq 2 ] && [ $SECOND_EXIT_CODE -eq 0 ]; then
        print_success "Terraform shows changes only on first run (expected for new resources)"
    else
        print_error "Terraform is NOT idempotent - changes detected on re-run (exit codes: $FIRST_EXIT_CODE, $SECOND_EXIT_CODE)"
    fi

    # Clean up
    rm -f tfplan1 tfplan2

    cd ..
}

# Test Ansible idempotency
test_ansible_idempotency() {
    print_header "Testing Ansible Idempotency"

    cd ansible || exit 1

    # Check if instances are available
    print_info "Checking for running instances..."
    INSTANCE_COUNT=$(ansible-inventory -i inventory/aws_ec2.yml --list 2>/dev/null | jq -r '.aws_ec2.hosts | length' || echo "0")

    if [ "$INSTANCE_COUNT" -eq "0" ]; then
        print_info "No instances found - skipping Ansible idempotency test"
        cd ..
        return
    fi

    print_info "Found $INSTANCE_COUNT instance(s)"

    # First run
    print_info "Running Ansible playbook (first run)..."
    ansible-playbook playbooks/webserver.yml -v > /tmp/ansible_run1.log 2>&1
    FIRST_CHANGED=$(grep -c "changed=" /tmp/ansible_run1.log || echo "0")

    # Second run (should show no changes)
    print_info "Running Ansible playbook (second run)..."
    ansible-playbook playbooks/webserver.yml -v > /tmp/ansible_run2.log 2>&1
    SECOND_CHANGED=$(grep -c "changed=" /tmp/ansible_run2.log || echo "0")

    # Check for "changed=0" in second run
    if grep -q "changed=0" /tmp/ansible_run2.log; then
        print_success "Ansible is idempotent - no changes on second run"
    else
        print_error "Ansible is NOT idempotent - detected changes on second run"
        print_info "First run changes: $FIRST_CHANGED"
        print_info "Second run changes: $SECOND_CHANGED"
    fi

    # Clean up
    rm -f /tmp/ansible_run1.log /tmp/ansible_run2.log

    cd ..
}

# Test state file consistency
test_state_consistency() {
    print_header "Testing State File Consistency"

    cd terraform || exit 1

    # Check if state file exists
    if terraform state list > /dev/null 2>&1; then
        print_success "Terraform state is accessible"

        # Check for state drift
        print_info "Checking for state drift..."
        if terraform plan -detailed-exitcode > /dev/null 2>&1; then
            print_success "No state drift detected"
        elif [ $? -eq 2 ]; then
            print_error "State drift detected - infrastructure has changes"
        else
            print_error "Error checking state drift"
        fi
    else
        print_info "No Terraform state found (infrastructure not deployed)"
    fi

    cd ..
}

# Test resource recreation prevention
test_resource_stability() {
    print_header "Testing Resource Stability"

    cd terraform || exit 1

    # Check if any resources will be destroyed and recreated
    print_info "Checking for resource replacements..."
    PLAN_OUTPUT=$(terraform plan -no-color 2>&1)

    if echo "$PLAN_OUTPUT" | grep -q "must be replaced"; then
        print_error "Resources will be replaced (not idempotent)"
        echo "$PLAN_OUTPUT" | grep "must be replaced"
    else
        print_success "No resources will be replaced"
    fi

    cd ..
}

# Test workflow idempotency
test_workflow_idempotency() {
    print_header "Testing Workflow Configuration"

    # Check for proper state locking configuration
    if grep -q "dynamodb_table" terraform/backend.tf; then
        print_success "State locking is configured"
    else
        print_error "State locking is NOT configured"
    fi

    # Check for lifecycle rules
    if grep -q "lifecycle {" terraform/modules/*/main.tf; then
        print_success "Lifecycle rules are defined"
    else
        print_error "No lifecycle rules found"
    fi

    # Check for ignore_changes
    if grep -q "ignore_changes" terraform/modules/*/main.tf; then
        print_success "ignore_changes directives are used"
    else
        print_info "No ignore_changes directives found (may cause drift)"
    fi
}

# Test Ansible check mode
test_ansible_check_mode() {
    print_header "Testing Ansible Check Mode"

    cd ansible || exit 1

    # Check if instances are available
    INSTANCE_COUNT=$(ansible-inventory -i inventory/aws_ec2.yml --list 2>/dev/null | jq -r '.aws_ec2.hosts | length' || echo "0")

    if [ "$INSTANCE_COUNT" -eq "0" ]; then
        print_info "No instances found - skipping Ansible check mode test"
        cd ..
        return
    fi

    # Run in check mode
    print_info "Running Ansible in check mode..."
    if ansible-playbook playbooks/webserver.yml --check > /dev/null 2>&1; then
        print_success "Ansible check mode passed"
    else
        print_error "Ansible check mode failed"
    fi

    cd ..
}

# Test configuration validation
test_configuration_validation() {
    print_header "Testing Configuration Validation"

    # Terraform validation
    cd terraform || exit 1
    if terraform validate > /dev/null 2>&1; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform configuration is invalid"
    fi
    cd ..

    # Ansible syntax check
    cd ansible || exit 1
    if ansible-playbook playbooks/webserver.yml --syntax-check > /dev/null 2>&1; then
        print_success "Ansible playbook syntax is valid"
    else
        print_error "Ansible playbook syntax is invalid"
    fi
    cd ..
}

# Main execution
main() {
    print_header "Infrastructure Idempotency Test Suite"
    echo ""

    # Run all tests
    test_configuration_validation
    echo ""

    test_workflow_idempotency
    echo ""

    test_terraform_idempotency
    echo ""

    test_state_consistency
    echo ""

    test_resource_stability
    echo ""

    test_ansible_check_mode
    echo ""

    test_ansible_idempotency
    echo ""

    # Summary
    print_header "Test Summary"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All idempotency tests passed!"
        exit 0
    else
        print_error "Some idempotency tests failed"
        exit 1
    fi
}

# Run main function
main

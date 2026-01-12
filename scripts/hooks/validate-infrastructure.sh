#!/bin/bash
# Pre-commit hook: Infrastructure Validation
# Validates infrastructure configuration consistency

set -e

echo "🔍 Validating infrastructure configuration..."

ERRORS=0

# Check Terraform variable consistency
echo "Checking Terraform variable consistency..."
if [ -d "terraform" ]; then
    # Check that all required variables are defined
    REQUIRED_VARS=("environment" "region")

    for var in "${REQUIRED_VARS[@]}"; do
        if grep -r "var\.$var" terraform/ > /dev/null 2>&1; then
            if ! grep -r "variable \"$var\"" terraform/ > /dev/null 2>&1; then
                echo "  ❌ Variable '$var' is used but not defined"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    done
fi

# Check Ansible inventory structure
echo "Checking Ansible inventory structure..."
if [ -d "ansible/inventories" ]; then
    ENVIRONMENTS=("dev" "staging" "prod")

    for env in "${ENVIRONMENTS[@]}"; do
        if [ -d "ansible/inventories/$env" ]; then
            if [ ! -f "ansible/inventories/$env/hosts.yml" ] && [ ! -f "ansible/inventories/$env/hosts" ]; then
                echo "  ⚠️  Missing hosts file for environment: $env"
            fi
        fi
    done
fi

# Check for hardcoded IPs or credentials
echo "Checking for hardcoded values..."
PATTERNS=(
    "password\s*=\s*['\"][^'\"]+['\"]"
    "secret\s*=\s*['\"][^'\"]+['\"]"
    "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
)

for pattern in "${PATTERNS[@]}"; do
    if git diff --cached | grep -iE "$pattern" > /dev/null 2>&1; then
        echo "  ⚠️  Found potential hardcoded value: $pattern"
        echo "     Consider using variables or secrets management"
    fi
done

# Check for required documentation
echo "Checking documentation..."
REQUIRED_DOCS=("README.md" "docs/DEPLOYMENT.md")

for doc in "${REQUIRED_DOCS[@]}"; do
    if [ ! -f "$doc" ]; then
        echo "  ⚠️  Missing documentation: $doc"
    fi
done

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "❌ Found $ERRORS validation error(s)"
    exit 1
fi

echo "✅ Infrastructure validation complete"
exit 0

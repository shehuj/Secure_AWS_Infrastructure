#!/bin/bash
# Pre-commit hook: Terraform Cost Estimation
# Estimates the cost of infrastructure changes

set -e

echo "🔍 Estimating Terraform costs..."

# Check if infracost is installed
if ! command -v infracost &> /dev/null; then
    echo "⚠️  Infracost not installed. Skipping cost estimation."
    echo "   Install with: brew install infracost (macOS) or see https://www.infracost.io/docs/"
    exit 0
fi

# Find terraform directories
TERRAFORM_DIRS=$(find terraform -type d -name "*.tf" -o -name "main.tf" | xargs -n1 dirname | sort -u)

if [ -z "$TERRAFORM_DIRS" ]; then
    echo "No Terraform files found. Skipping."
    exit 0
fi

# Run cost estimation
for dir in $TERRAFORM_DIRS; do
    echo "📊 Estimating costs for: $dir"

    cd "$dir" || continue

    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        terraform init -backend=false > /dev/null 2>&1 || true
    fi

    # Run infracost
    if infracost breakdown --path . --format table 2>/dev/null; then
        echo "✅ Cost estimation complete for $dir"
    else
        echo "⚠️  Could not estimate costs for $dir"
    fi

    cd - > /dev/null || exit
    echo ""
done

echo "✅ Cost estimation complete"
exit 0

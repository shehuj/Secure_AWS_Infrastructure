#!/bin/bash
# Pre-commit hook: Ansible Syntax Check
# Validates Ansible playbooks syntax

set -e

echo "🔍 Checking Ansible syntax..."

# Check if ansible-playbook is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "⚠️  ansible-playbook not installed. Skipping syntax check."
    exit 0
fi

# Find all playbooks
PLAYBOOKS=$(find ansible/playbooks -name "*.yml" -o -name "*.yaml" 2>/dev/null || true)

if [ -z "$PLAYBOOKS" ]; then
    echo "No Ansible playbooks found. Skipping."
    exit 0
fi

ERRORS=0

for playbook in $PLAYBOOKS; do
    echo "Checking: $playbook"

    if ansible-playbook "$playbook" --syntax-check > /dev/null 2>&1; then
        echo "  ✅ Syntax OK"
    else
        echo "  ❌ Syntax error found!"
        ansible-playbook "$playbook" --syntax-check
        ERRORS=$((ERRORS + 1))
    fi
done

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "❌ Found $ERRORS playbook(s) with syntax errors"
    exit 1
fi

echo "✅ All Ansible playbooks passed syntax check"
exit 0

#!/bin/bash
# Pre-commit hook: Check for Sensitive Data
# Prevents committing sensitive data

set -e

echo "🔍 Checking for sensitive data..."

ERRORS=0

# Files that should never be committed
FORBIDDEN_FILES=(
    "*.pem"
    "*.key"
    "*.p12"
    "*.pfx"
    "*_rsa"
    "*_dsa"
    "*.credentials"
    ".env"
    ".env.local"
    ".env.*.local"
    "credentials.json"
    "secrets.yml"
    "secrets.yaml"
)

# Check for forbidden files
for pattern in "${FORBIDDEN_FILES[@]}"; do
    if git diff --cached --name-only | grep -iE "$pattern" > /dev/null 2>&1; then
        echo "  ❌ Forbidden file pattern detected: $pattern"
        echo "     These files should not be committed!"
        ERRORS=$((ERRORS + 1))
    fi
done

# Sensitive patterns in file content
SENSITIVE_PATTERNS=(
    "AKIA[0-9A-Z]{16}"                           # AWS Access Key
    "-----BEGIN (RSA |DSA )?PRIVATE KEY-----"    # Private keys
    "password\s*[:=]\s*['\"][^'\"]{8,}['\"]"     # Password assignments
    "api[_-]?key\s*[:=]\s*['\"][^'\"]+['\"]"     # API keys
    "secret[_-]?key\s*[:=]\s*['\"][^'\"]+['\"]"  # Secret keys
    "token\s*[:=]\s*['\"][^'\"]+['\"]"           # Tokens
)

# Check staged files for sensitive patterns
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

for file in $STAGED_FILES; do
    # Skip binary files
    if file "$file" | grep -q "text"; then
        for pattern in "${SENSITIVE_PATTERNS[@]}"; do
            if grep -iE "$pattern" "$file" > /dev/null 2>&1; then
                echo "  ❌ Potential sensitive data in: $file"
                echo "     Pattern: $pattern"
                ERRORS=$((ERRORS + 1))
            fi
        done
    fi
done

# Check for AWS credentials in diff
if git diff --cached | grep -iE "aws_access_key_id|aws_secret_access_key" > /dev/null 2>&1; then
    echo "  ❌ AWS credentials detected in staged changes!"
    echo "     Use AWS Secrets Manager or environment variables instead"
    ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "❌ Found $ERRORS potential sensitive data issue(s)"
    echo ""
    echo "If this is a false positive, you can:"
    echo "1. Update .secrets.baseline with: detect-secrets scan > .secrets.baseline"
    echo "2. Skip this check with: git commit --no-verify"
    echo ""
    exit 1
fi

echo "✅ No sensitive data detected"
exit 0

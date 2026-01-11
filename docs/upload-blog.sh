#!/bin/bash
# Quick blog upload script

echo "=========================================="
echo "Ghost Blog Uploader - Quick Start"
echo "=========================================="
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed"
    exit 1
fi

# Check if pip packages are installed
echo "Checking dependencies..."
python3 -c "import jwt, requests" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "📦 Installing required packages..."
    pip3 install PyJWT requests
    echo ""
fi

# Run the upload script
python3 "$(dirname "$0")/upload-to-ghost.py"

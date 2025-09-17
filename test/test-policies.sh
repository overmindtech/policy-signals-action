#!/bin/bash
# Test script for validating policies locally WITHOUT submitting to Overmind
# This is for testing your policies work correctly before using in production

set -e

echo "==================================="
echo "Policy Validation Test Script"
echo "==================================="
echo ""

# Configuration
POLICIES_PATH="${1:-./policies}"
PLAN_FILE="${2:-./test/fixtures/sample-plan.json}"

echo "Configuration:"
echo "  Policies Path: $POLICIES_PATH"
echo "  Plan File: $PLAN_FILE"
echo ""

# Install Conftest if not present
if ! command -v conftest &> /dev/null; then
    echo "Installing Conftest..."
    
    # Detect OS and install accordingly
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install conftest
        else
            echo "Homebrew not found. Installing Conftest directly..."
            CONFTEST_VERSION="0.46.0"
            curl -L -o conftest.tar.gz "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Darwin_x86_64.tar.gz"
            tar xzf conftest.tar.gz
            sudo mv conftest /usr/local/bin
            rm conftest.tar.gz
        fi
    else
        # Linux
        CONFTEST_VERSION="0.46.0"
        if command -v wget &> /dev/null; then
            wget -q "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz"
        else
            curl -L -o conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz"
        fi
        tar xzf conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz
        sudo mv conftest /usr/local/bin
        rm conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz
    fi
fi

# Check if terraform plan exists
if [ ! -f "$PLAN_FILE" ]; then
    echo "ERROR: Terraform plan file not found: $PLAN_FILE"
    echo ""
    echo "To create a test plan:"
    echo "  cd test/terraform"
    echo "  terraform init"
    echo "  terraform plan -out=tfplan"
    echo "  terraform show -json tfplan > ../fixtures/sample-plan.json"
    exit 1
fi

# Check if policies exist
if [ ! -d "$POLICIES_PATH" ]; then
    echo "ERROR: Policies directory not found: $POLICIES_PATH"
    exit 1
fi

echo "Running policy checks..."
echo "========================"

# Run Conftest and show results
set +e
conftest test --policy "$POLICIES_PATH" --all-namespaces "$PLAN_FILE"
CONFTEST_EXIT=$?
set -e

echo ""

if [ $CONFTEST_EXIT -eq 0 ]; then
    echo "✅ SUCCESS: No policy violations found!"
    echo ""
    echo "Your policies passed all checks. The action would not submit any signals."
else
    echo "⚠️  VIOLATIONS FOUND: The action would submit the following signals:"
    echo ""
    
    # Parse and display what would be submitted
    conftest test --policy "$POLICIES_PATH" --all-namespaces --output json "$PLAN_FILE" 2>/dev/null | \
        jq -r '.[] | select(.failures != null) | .namespace as $ns | .failures[] | "  Signal: Policy: \($ns)\n  Message: \(.msg)\n"'
    
    echo "These violations would be submitted as Custom Signals with severity -3"
fi

echo ""
echo "==================================="
echo "Test complete!"
echo ""
echo "To test with real Overmind submission:"
echo "  1. Create a real PR with terraform changes"
echo "  2. Use the GitHub Action in your workflow"
echo "  3. The action will submit signals linked to your actual PR"

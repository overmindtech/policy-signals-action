#!/bin/bash

# Real Overmind Policy Signals Test
# 
# This script demonstrates the GitHub Action functionality by submitting
# actual Custom Signals to Overmind. Use this to test your setup.
#
# USAGE:
#   export OVERMIND_API_KEY="your_actual_api_key_here"
#   export TICKET_LINK="https://github.com/your-org/your-repo/pull/123"
#   ./test/test_real_submission.sh
#
# REQUIREMENTS:
#   - Overmind CLI installed (brew install overmindtech/overmind/overmind-cli)
#   - Valid Overmind API key
#   - A real GitHub PR URL where you want the signals to appear
#
# WARNING: This submits real signals to Overmind! Only use for testing.
#          The signals will appear in your Overmind dashboard and PR comments.

set -e

echo "🚀 Testing Real Overmind Policy Signals Submission"
echo "================================================="
echo ""

# Configuration
export OVERMIND_API_KEY="${OVERMIND_API_KEY:-ovm_api_YOUR_KEY_HERE}"
TICKET_LINK="${TICKET_LINK:-https://github.com/your-org/your-repo/pull/123}"
POLICIES_PATH="./policies"
PLAN_FILE="./test/terraform/test/fixtures/sample-plan.json"
SEVERITY="-3"

# Validate configuration
if [[ "$OVERMIND_API_KEY" == "ovm_api_YOUR_KEY_HERE" ]]; then
    echo "❌ ERROR: Please set your real Overmind API key:"
    echo "   export OVERMIND_API_KEY=\"your_actual_api_key\""
    exit 1
fi

if [[ "$TICKET_LINK" == "https://github.com/your-org/your-repo/pull/123" ]]; then
    echo "❌ ERROR: Please set a real GitHub PR URL:"
    echo "   export TICKET_LINK=\"https://github.com/your-org/your-repo/pull/123\""
    exit 1
fi

echo "Configuration:"
echo "  API Key: ${OVERMIND_API_KEY:0:20}..."
echo "  Ticket Link: $TICKET_LINK"
echo "  Policies: $POLICIES_PATH"
echo "  Plan File: $PLAN_FILE"
echo ""

# Check if Overmind CLI is installed
if ! command -v overmind &> /dev/null; then
    echo "❌ Overmind CLI not found. Please install it first:"
    echo "   curl -sL https://dl.cloudsmith.io/public/overmind/tools/setup.deb.sh | sudo -E bash"
    echo "   sudo apt-get update && sudo apt-get install -y overmind-cli"
    echo ""
    echo "   Or on macOS:"
    echo "   brew install overmindtech/overmind/overmind-cli"
    exit 1
fi

echo "✅ Overmind CLI version: $(overmind --version)"
echo ""

# Run policy checks
echo "🔍 Running policy checks..."
set +e  # Don't exit on conftest failures

# Create temp directory for test outputs
TEMP_DIR=$(mktemp -d)
VIOLATIONS_FILE="$TEMP_DIR/violations.json"

conftest test \
  --policy "$POLICIES_PATH" \
  --all-namespaces \
  --output json \
  "$PLAN_FILE" > "$VIOLATIONS_FILE"
CONFTEST_EXIT_CODE=$?
set -e

if [ $CONFTEST_EXIT_CODE -eq 0 ]; then
    echo "✅ No policy violations found"
    rm -rf "$TEMP_DIR"
    exit 0
fi

echo "⚠️  Policy violations detected!"
echo ""

# Show violations summary
echo "Violations Summary:"
echo "==================="
cat "$VIOLATIONS_FILE" | jq -r '.[] | select(.failures != null) | .failures[] | "- \(.msg)"'
echo ""

# Submit each violation as a Custom Signal
echo "📡 Submitting signals to Overmind..."
echo ""

SIGNAL_COUNT=0

# Submit all violations as Custom Signals
cat "$VIOLATIONS_FILE" | jq -c '.[] | select(.failures != null) | .namespace as $ns | .failures[] | {namespace: $ns, msg: .msg, query: (.metadata.query // "unknown")}' | while read -r violation; do
    NAMESPACE=$(echo "$violation" | jq -r '.namespace')
    MESSAGE=$(echo "$violation" | jq -r '.msg')
    QUERY=$(echo "$violation" | jq -r '.query')
    
    # Create a more readable policy name
    POLICY_NAME=$(echo "$QUERY" | sed 's/data\.//' | sed 's/\.deny$//' | sed 's/\.warn$//')
    
    echo "Submitting signal:"
    echo "  Policy: $POLICY_NAME"
    echo "  Message: ${MESSAGE:0:80}..."
    
    # Submit signal to Overmind
    overmind changes submit-signal \
        --title "Policy Violation: $POLICY_NAME" \
        --description "$MESSAGE" \
        --value "$SEVERITY" \
        --category "Policies" \
        --ticket-link "$TICKET_LINK"
    
    echo "  ✅ Signal submitted successfully"
    echo ""
    
    SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
done

# Count total violations for final message
TOTAL_VIOLATIONS=$(cat "$VIOLATIONS_FILE" | jq '[.[] | select(.failures != null) | .failures[]] | length')

echo "🎉 Successfully submitted $TOTAL_VIOLATIONS Custom Signals to Overmind!"
echo ""
echo "Check your Overmind dashboard and PR: $TICKET_LINK"

# Clean up temp files
rm -rf "$TEMP_DIR"
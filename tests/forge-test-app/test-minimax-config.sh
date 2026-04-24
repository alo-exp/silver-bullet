#!/bin/bash
# MiniMax API max_tokens configuration test
# Verifies that max_tokens is properly set

cd /Users/shafqat/Documents/Projects/silver-bullet/tests/forge-test-app

echo "=============================================="
echo "MiniMax Max Tokens Verification Test"
echo "=============================================="
echo ""

# Get config
MODEL=$(forge config get model 2>/dev/null)
MAX_TOKENS=$(forge config list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk 'NR==27 {print $3}')

echo "Configuration:"
echo "  Model: $MODEL"
echo "  max_tokens: $MAX_TOKENS"
echo ""

# Verify max_tokens is set to 196608 (192K)
if [[ "$MAX_TOKENS" == "196608" ]]; then
    echo "PASS: max_tokens is correctly set to 196608 (192K tokens)"
else
    echo "FAIL: max_tokens is $MAX_TOKENS, expected 196608"
fi

# Quick API response test
echo ""
echo "Test: Quick API response test..."
RESPONSE=$(forge -p "Respond with exactly: TEST_COMPLETE" 2>&1)

if echo "$RESPONSE" | grep -q "TEST_COMPLETE"; then
    echo "PASS: API responding correctly"
else
    echo "FAIL: Unexpected API response"
fi

# Check for proper completion status
if echo "$RESPONSE" | grep -q "Finished"; then
    echo "PASS: Response completed properly"
else
    echo "WARN: No explicit completion status"
fi

echo ""
echo "=============================================="
echo "Test Complete"
echo "=============================================="

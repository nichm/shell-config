#!/usr/bin/env bash
# =============================================================================
# 🔐 1PASSWORD QUICK LOGIN
# =============================================================================
# Quick helper to sign in and export session token
# =============================================================================

set -euo pipefail

# Get account info
ACCOUNT_SHORTHAND=$(op account list --format=json 2>/dev/null \
    | jq -r '.[0].shorthand // .[0].user_uuid // empty' 2>/dev/null)

if [[ -z "$ACCOUNT_SHORTHAND" ]]; then
    echo "❌ No 1Password account found. Run: op account add"
    exit 1
fi

SESSION_VAR="OP_SESSION_${ACCOUNT_SHORTHAND}"

# Check if already logged in
if op whoami &>/dev/null 2>&1; then
    echo "✅ Already logged in as: $(op whoami 2>/dev/null | grep Email | awk '{print $2}')"
    exit 0
fi

# Sign in and export session token
echo "🔐 Signing in to 1Password..."
SESSION_TOKEN=$(op signin --account "$ACCOUNT_SHORTHAND" --raw 2>&1)

if [[ -n "$SESSION_TOKEN" ]]; then
    export "$SESSION_VAR=$SESSION_TOKEN"
    echo "✅ Logged in successfully!"
    echo "   Session token exported to: $SESSION_VAR"
    op whoami 2>/dev/null | head -3
else
    echo "❌ Failed to sign in. Make sure:"
    echo "   1. 1Password desktop app is running and unlocked"
    echo "   2. You have biometric/Touch ID enabled"
    exit 1
fi

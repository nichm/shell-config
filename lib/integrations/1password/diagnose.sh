#!/usr/bin/env bash
# =============================================================================
# 🔍 1PASSWORD CLI DIAGNOSTIC TOOL
# =============================================================================
# Diagnoses and fixes common 1Password CLI authentication issues
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared colors library
source "$SCRIPT_DIR/../core/colors.sh"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🔍 1Password CLI Diagnostic${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check 1: CLI installed?
log_info "Checking if 1Password CLI is installed..."
if command_exists "op"; then
    CLI_VERSION=$(op --version 2>/dev/null || echo "unknown")
    log_success "1Password CLI installed: $CLI_VERSION"
else
    log_error "1Password CLI not found. Install with: brew install 1password-cli"
    exit 1
fi

# Check 2: Desktop app running?
log_info "Checking if 1Password desktop app is running..."
if pgrep -x "1Password" >/dev/null 2>&1 || pgrep -x "1Password 8" >/dev/null 2>&1 || pgrep -x "1Password 7" >/dev/null 2>&1; then
    log_success "1Password desktop app is running"
else
    log_warning "1Password desktop app doesn't appear to be running"
    log_info "Please open and unlock the 1Password app"
fi

# Check 3: Accounts configured?
log_info "Checking configured accounts..."
ACCOUNTS=$(op account list --format=json 2>/dev/null || echo "[]")
if echo "$ACCOUNTS" | jq -e '. | length > 0' >/dev/null 2>&1; then
    ACCOUNT_COUNT=$(echo "$ACCOUNTS" | jq '. | length')
    log_success "Found $ACCOUNT_COUNT account(s)"
    echo "$ACCOUNTS" | jq -r '.[] | "  • \(.url) - \(.email)"'
else
    log_error "No accounts configured. Run: op account add"
    exit 1
fi

# Check 4: Current authentication status
log_info "Checking authentication status..."
if op whoami &>/dev/null 2>&1; then
    USER_INFO=$(op whoami 2>/dev/null)
    log_success "Authenticated as: $USER_INFO"
    AUTH_STATUS="authenticated"
else
    log_warning "Not currently authenticated"
    AUTH_STATUS="not_authenticated"
fi

# Check 5: Session tokens in environment
log_info "Checking for session tokens in environment..."
SESSION_VARS=$(env | grep -o '^OP_SESSION_[^=]*' 2>/dev/null || true)
if [[ -n "$SESSION_VARS" ]]; then
    log_success "Found session variables:"
    echo "$SESSION_VARS" | while read -r var; do
        echo "  • $var"
    done
else
    log_warning "No OP_SESSION_* variables found in environment"
fi

# Check 6: Can list items?
log_info "Testing item access..."
ITEM_COUNT=$(op item list --format=json 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
if [[ "$ITEM_COUNT" -gt 0 ]]; then
    log_success "Can access vault: $ITEM_COUNT items found"
else
    log_warning "Cannot list items (might need authentication)"
fi

# Check 7: Account shorthand detection
log_info "Detecting account shorthand..."
ACCOUNT_SHORTHAND=$(echo "$ACCOUNTS" | jq -r '.[0].shorthand // .[0].user_uuid // empty' 2>/dev/null || echo "")
if [[ -n "$ACCOUNT_SHORTHAND" ]]; then
    log_success "Account shorthand: $ACCOUNT_SHORTHAND"
    EXPECTED_SESSION_VAR="OP_SESSION_${ACCOUNT_SHORTHAND}"
    log_info "Expected session variable: $EXPECTED_SESSION_VAR"
else
    log_warning "Could not determine account shorthand"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Recommendations
echo ""
echo -e "${CYAN}💡 Recommendations:${NC}"
echo ""

if [[ "$AUTH_STATUS" == "not_authenticated" ]]; then
    echo -e "${YELLOW}To sign in:${NC}"
    if [[ -n "$ACCOUNT_SHORTHAND" ]]; then
        echo "  op signin --account $ACCOUNT_SHORTHAND"
    else
        ACCOUNT_URL=$(echo "$ACCOUNTS" | jq -r '.[0].url' 2>/dev/null || echo "")
        if [[ -n "$ACCOUNT_URL" ]]; then
            echo "  op signin --account $ACCOUNT_URL"
        else
            echo "  op signin"
        fi
    fi
    echo ""
    echo -e "${YELLOW}To get a session token (for shell-config):${NC}"
    if [[ -n "$ACCOUNT_SHORTHAND" ]]; then
        echo "  export OP_SESSION_${ACCOUNT_SHORTHAND}=\$(op signin --account $ACCOUNT_SHORTHAND --raw)"
    else
        ACCOUNT_URL=$(echo "$ACCOUNTS" | jq -r '.[0].url' 2>/dev/null || echo "")
        if [[ -n "$ACCOUNT_URL" ]]; then
            echo "  export OP_SESSION_<shorthand>=\$(op signin --account $ACCOUNT_URL --raw)"
        else
            echo "  export OP_SESSION_<shorthand>=\$(op signin --raw)"
        fi
    fi
    echo ""
fi

if [[ "$ITEM_COUNT" -eq 0 ]] && [[ "$AUTH_STATUS" == "not_authenticated" ]]; then
    echo -e "${YELLOW}If you can list items but 'op whoami' fails:${NC}"
    echo "  This means you're authenticated but the session token isn't exported."
    echo "  Run the signin command above to export the session token."
    echo ""
fi

echo -e "${YELLOW}To reload shell-config session:${NC}"
echo "  source ~/.shell-config/lib/integrations/1password/secrets.sh"
echo "  _op_get_session"
echo ""

echo -e "${YELLOW}To test authentication:${NC}"
echo "  op whoami"
echo "  op item list | head -5"
echo ""

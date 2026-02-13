#!/usr/bin/env bash
# =============================================================================
# push/pre-push.sh - Pre-push validation stage
# =============================================================================
# Runs final validation checks before pushing to remote:
#   - Unit tests (redundant check for safety)
#   - Secrets scanning (redundant check for defense in depth)
# =============================================================================
set -euo pipefail

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Run pre-push validation checks
run_pre_push_checks() {
    local tmpdir
    local failed_checks=()
    local failed=0

    # Create temp directory
    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    # Intentional expansion: capture value while variable is in scope
    trap "command rm -rf '$tmpdir'" EXIT INT TERM

    log_info "🚀 Running pre-push validation..."

    # Run unit tests (defense in depth - already run in pre-commit)
    if ! run_push_unit_tests "$tmpdir"; then
        failed_checks+=("unit-tests")
        failed=1
    fi

    # Run secrets scan (defense in depth - already run in pre-commit)
    if ! run_push_secrets_check "$tmpdir"; then
        failed_checks+=("secrets-scan")
        failed=1
    fi

    if [[ $failed -eq 1 ]]; then
        display_push_blocked_message "${failed_checks[@]}"
        return 1
    else
        log_success "✅ All pre-push checks passed!"
        return 0
    fi
}

# Unit tests for push (redundant but safer)
run_push_unit_tests() {
    local tmpdir="$1"

    if [[ -f "package.json" ]]; then
        if grep -q '"test":' package.json 2>/dev/null; then
            if command_exists "bun"; then
                if ! timeout "${SC_HOOK_TIMEOUT_LONG:-60}" bun test >"$tmpdir/push-test-output" 2>&1; then
                    echo "error" >"$tmpdir/push-test-errors"
                    return 1
                fi
            fi
        fi
    fi
    echo -e "${GREEN}✓${NC} 🧪 Push unit tests complete" >&2
    return 0
}

# Secrets scan for push (defense in depth)
run_push_secrets_check() {
    local tmpdir="$1"

    if command_exists "gitleaks"; then
        local gitleaks_config="$SHELL_CONFIG_DIR/lib/validation/validators/security/config/gitleaks.toml"
        local gitleaks_cmd=(gitleaks protect --staged)
        if [[ -f "$gitleaks_config" ]]; then
            gitleaks_cmd+=(--config "$gitleaks_config")
        fi

        if ! timeout "${SC_GITLEAKS_TIMEOUT:-10}" "${gitleaks_cmd[@]}" >/dev/null 2>&1; then
            echo "error" >"$tmpdir/push-secrets-errors"
            return 1
        fi
    fi
    echo -e "${GREEN}✓${NC} 🕵️  Push secrets scan complete" >&2
    return 0
}

# Display push blocked message
display_push_blocked_message() {
    local failed_checks=("$@")

    echo "" >&2
    log_error "🛑 Push blocked — fix these first"
    echo "" >&2
    echo "❌ Failed checks:" >&2
    for check in "${failed_checks[@]}"; do
        echo "   - $check" >&2
    done
    echo "" >&2
    echo "💡 Fix the issues or use:" >&2
    echo "   git push --no-verify" >&2
    echo "" >&2
}

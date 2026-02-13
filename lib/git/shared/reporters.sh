#!/usr/bin/env bash
# =============================================================================
# 📊 Reporter Utilities for Git Hooks
# =============================================================================
# Shared functions for reporting hook status and results
# Sources canonical colors from lib/core/colors.sh
# =============================================================================
set -euo pipefail

# Exit if script is sourced more than once
[[ -n "${_GIT_REPORTERS_LOADED:-}" ]] && return 0
readonly _GIT_REPORTERS_LOADED=1

# Get script directory
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _GIT_REPORTERS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    _GIT_REPORTERS_SCRIPT_DIR="${HOME}/.shell-config/lib/git/shared"
fi

# Source canonical colors from core
# shellcheck source=../../core/colors.sh
source "$_GIT_REPORTERS_SCRIPT_DIR/../../core/colors.sh"

# Report hook start
# Usage: report_hook_start "pre-push" "Running pre-push checks"
report_hook_start() {
    local hook_name="$1"
    local message="${2:-Running $hook_name hook}"
    # Use printf to prevent terminal injection from untrusted variables
    printf "${COLOR_BLUE}🪝 [%s]${COLOR_RESET} %s\n" "$hook_name" "$message" >&2
}

# Report hook success
# Usage: report_hook_success "pre-push"
report_hook_success() {
    local hook_name="$1"
    printf '%b✅ [%s]%b All checks passed\n' "${COLOR_GREEN}" "$hook_name" "${COLOR_RESET}" >&2
}

# Report info message
# Usage: report_info "Checking 5 files..."
report_info() {
    local message="$1"
    printf '%bℹ️  %b%s\n' "${COLOR_BLUE}" "${COLOR_RESET}" "$message" >&2
}

# Report file being checked
# Usage: report_file_check "path/to/file.ts" "Syntax check"
report_file_check() {
    local file="$1"
    local check_type="${2:-Checking}"
    printf '   %b•%b %s: %s\n' "${COLOR_BLUE}" "${COLOR_RESET}" "$check_type" "$file" >&2
}

# Report file check result
# Usage: report_file_result "path/to/file.ts" "pass|fail|skip" "message"
report_file_result() {
    local file="$1"
    local result="$2"
    local message="${3:-}"

    case "$result" in
        pass)
            printf '   %b✓%b %s%s\n' "${COLOR_GREEN}" "${COLOR_RESET}" "$file" "${message:+: $message}" >&2
            ;;
        fail)
            # Use printf to prevent terminal injection from untrusted file paths
            printf '   %b✗%b %s%s\n' "${COLOR_RED}" "${COLOR_RESET}" "$file" "${message:+: $message}" >&2
            ;;
        skip)
            printf '   %b⏭%b %s%s\n' "${COLOR_YELLOW}" "${COLOR_RESET}" "$file" "${message:+: $message}" >&2
            ;;
    esac
}

# Report validation error
# Usage: report_validation_error "file" "line" "message" "details"
report_validation_error() {
    local file="$1"
    local line="${2:-}"
    local message="$3"
    local details="${4:-}"

    printf '%b❌ %s%b\n' "${COLOR_RED}" "$message" "${COLOR_RESET}" >&2
    [[ -n "$file" ]] && printf '   File: %s%s\n' "$file" "${line:+:$line}" >&2
    [[ -n "$details" ]] && printf '   %s\n' "$details" >&2
}

# Report validation success
# Usage: report_validation_success "All tests passed"
report_validation_success() {
    local message="$1"
    printf '%b✓%b %s\n' "${COLOR_GREEN}" "${COLOR_RESET}" "$message" >&2
}

# Note: log_warning is sourced from lib/core/colors.sh (sourced above)

# Fail the hook with message
# Usage: hook_fail "Validation failed" "git push --no-verify"
hook_fail() {
    local message="$1"
    local bypass="${2:-}"

    printf '\n' >&2
    printf '%b❌ %s%b\n' "${COLOR_RED}" "$message" "${COLOR_RESET}" >&2
    [[ -n "$bypass" ]] && printf '   💡 Bypass: %s\n' "$bypass" >&2
    printf '\n' >&2
    exit 1
}

# Export functions
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f report_hook_start 2>/dev/null || true
    export -f report_hook_success 2>/dev/null || true
    export -f report_info 2>/dev/null || true
    export -f report_file_check 2>/dev/null || true
    export -f report_file_result 2>/dev/null || true
    export -f report_validation_error 2>/dev/null || true
    export -f report_validation_success 2>/dev/null || true
    export -f log_warning 2>/dev/null || true
    export -f hook_fail 2>/dev/null || true
fi

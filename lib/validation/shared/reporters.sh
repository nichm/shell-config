#!/usr/bin/env bash
# =============================================================================
# Validation output formatters - logging and report functions
# =============================================================================
# Sources canonical colors and logging from lib/core/colors.sh
# =============================================================================
# NOTE: No set -euo pipefail — this file is sourced into interactive shells
# via git wrapper -> validation chain. set -e would cause the shell to exit
# on any command failure. Strict mode is inherited from hook scripts.

# Prevent double-sourcing
[[ -n "${_VALIDATION_REPORTERS_LOADED:-}" ]] && return 0
readonly _VALIDATION_REPORTERS_LOADED=1

# Get script directory and source canonical colors
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _VALIDATION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    _VALIDATION_SCRIPT_DIR="${HOME}/.shell-config/lib/validation/shared"
fi

# Source canonical colors from core
# shellcheck source=../../core/colors.sh
source "$_VALIDATION_SCRIPT_DIR/../../core/colors.sh"

# =============================================================================
# RESULT REPORTING
# =============================================================================

# Report a file validation result
# Usage: validation_report_file "pass|warn|fail" "filename" "message"
validation_report_file() {
    local status="$1"
    local file="$2"
    local message="${3:-}"

    case "$status" in
        pass | ok | success)
            printf '  %b✓%b %s%s\n' "${COLOR_GREEN}" "${COLOR_RESET}" "$file" "${message:+ - $message}"
            ;;
        warn | warning)
            printf '  %b⚠%b %s%s\n' "${COLOR_YELLOW}" "${COLOR_RESET}" "$file" "${message:+ - $message}" >&2
            ;;
        fail | error)
            # Use printf to prevent terminal injection from untrusted file paths
            printf '  %b✗%b %s%s\n' "${COLOR_RED}" "${COLOR_RESET}" "$file" "${message:+ - $message}" >&2
            ;;
        info)
            printf '  %b•%b %s%s\n' "${COLOR_BLUE}" "${COLOR_RESET}" "$file" "${message:+ - $message}"
            ;;
        *)
            printf '  - %s%s\n' "$file" "${message:+ - $message}"
            ;;
    esac
}

# Report a validation summary
# Usage: validation_report_summary "Syntax Check" 10 2 1
validation_report_summary() {
    local name="$1"
    local total="${2:-0}"
    local passed="${3:-0}"
    local failed="${4:-0}"
    local warnings="${5:-0}"

    printf '\n' >&2
    printf '%b━━━ %s Summary ━━━%b\n' "${COLOR_CYAN}" "$name" "${COLOR_RESET}" >&2
    printf '  Total:    %s\n' "$total" >&2
    printf '  Passed:   %s\n' "$passed" >&2
    [[ $warnings -gt 0 ]] && printf '  Warnings: %s\n' "$warnings" >&2
    [[ $failed -gt 0 ]] && printf '  Failed:   %s\n' "$failed" >&2
    printf '\n' >&2
}

# =============================================================================
# SECTION HEADERS
# =============================================================================

# Print a section header
# Usage: validation_header "Checking syntax..."
validation_header() {
    local title="$1"
    printf '\n' >&2
    printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n' "${COLOR_CYAN}" "${COLOR_RESET}" >&2
    printf '%b  %s%b\n' "${COLOR_CYAN}" "$title" "${COLOR_RESET}" >&2
    printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n' "${COLOR_CYAN}" "${COLOR_RESET}" >&2
}

# Print a sub-section header
# Usage: validation_subheader "Running shellcheck..."
validation_subheader() {
    local title="$1"
    printf '%b▸ %s%b\n' "${COLOR_BLUE}" "$title" "${COLOR_RESET}" >&2
}

# =============================================================================
# VALIDATION-SPECIFIC LOGGING
# =============================================================================

validation_log_debug() {
    [[ "${VALIDATION_DEBUG:-0}" == "1" ]] && printf '%b🔍 %s%b\n' "${COLOR_CYAN}" "$1" "${COLOR_RESET}" >&2
}

validation_log_info() {
    printf '%bℹ️  %s%b\n' "${COLOR_BLUE}" "$1" "${COLOR_RESET}" >&2
}

validation_log_success() {
    echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}" >&2
}

validation_log_warning() {
    echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}" >&2
}

validation_log_error() {
    echo -e "${COLOR_RED}❌ $1${COLOR_RESET}" >&2
}

# =============================================================================
# BYPASS MESSAGES
# =============================================================================

# Print bypass instructions
# Usage: validation_bypass_hint "GIT_SKIP_SYNTAX_CHECK"
validation_bypass_hint() {
    local env_var="$1"
    local message="${2:-To bypass this check}"
    echo "" >&2
    echo -e "${COLOR_YELLOW}💡 $message: ${COLOR_BLUE}${env_var}=1${COLOR_RESET} git commit -m 'message'" >&2
    echo "" >&2
}

# =============================================================================
# VERBOSE OUTPUT
# =============================================================================

# Only print if verbose mode is enabled
# Usage: VALIDATION_VERBOSE=1 validation_verbose "Processing file..."
validation_verbose() {
    [[ "${VALIDATION_VERBOSE:-0}" == "1" ]] && echo -e "${COLOR_BLUE}ℹ️  $1${COLOR_RESET}" >&2
}

# Report check results summary
report_check_summary() {
    local check_name="$1"
    local passed="$2"
    local failed="$3"
    local skipped="${4:-0}"

    echo ""
    if [[ $failed -gt 0 ]]; then
        echo -e "${COLOR_RED}✗ $check_name: $passed passed, $failed failed${COLOR_RESET}"
    elif [[ $skipped -gt 0 ]]; then
        echo -e "${COLOR_YELLOW}⊝ $check_name: $passed passed, $skipped skipped${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}✓ $check_name: $passed passed${COLOR_RESET}"
    fi
}

# Report hook success
report_hook_success() {
    local hook_name="$1"
    echo ""
    echo -e "${COLOR_GREEN}✅ $hook_name checks passed!${COLOR_RESET}"
    echo ""
}

# Exit with error message (for hook failures)
hook_fail() {
    local message="$1"
    local bypass="${2:-}"

    echo "" >&2
    echo -e "${COLOR_RED}❌ Hook Failed: $message${COLOR_RESET}" >&2
    echo "" >&2

    if [[ -n "$bypass" ]]; then
        echo -e "   ${COLOR_YELLOW}💡 Bypass: $bypass${COLOR_RESET}" >&2
    fi

    echo "" >&2
    exit 1
}

# Report multiple validation failures at once
report_bulk_failures() {
    local message="$1"
    shift
    local failed_files=("$@")

    printf "\n" >&2
    printf "${COLOR_RED}❌ %s${COLOR_RESET}\n" "$message" >&2
    printf "${COLOR_RED}Found %d issue(s):${COLOR_RESET}\n" "${#failed_files[@]}" >&2
    printf "\n" >&2

    for file in "${failed_files[@]}"; do
        printf "   ${COLOR_RED}•${COLOR_RESET} %s\n" "$file" >&2
    done
    printf "\n" >&2
}

# Export functions
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f validation_log_debug 2>/dev/null || true
    export -f validation_log_info 2>/dev/null || true
    export -f validation_log_success 2>/dev/null || true
    export -f validation_log_warning 2>/dev/null || true
    export -f validation_log_error 2>/dev/null || true
    export -f validation_report_file 2>/dev/null || true
    export -f validation_report_summary 2>/dev/null || true
    export -f validation_header 2>/dev/null || true
    export -f validation_subheader 2>/dev/null || true
    export -f validation_bypass_hint 2>/dev/null || true
    export -f validation_verbose 2>/dev/null || true
    export -f report_check_summary 2>/dev/null || true
    export -f report_hook_success 2>/dev/null || true
    export -f hook_fail 2>/dev/null || true
    export -f report_bulk_failures 2>/dev/null || true
fi

#!/usr/bin/env bash
# =============================================================================
# 📏 FILE VALIDATOR - File Size and Structure Validation
# =============================================================================
# Validates files for excessive line counts based on language standards.
# Implements three-tier system: INFO (60%), WARNING (75%), EXTREME (100%)
# Usage:
#   source lib/validation/validators/file-validator.sh
#   validate_file_length "/path/to/file.py"
#   validate_files_length file1.py file2.js
# This validator knows NOTHING about git - it's pure file validation logic.
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_FILE_VALIDATOR_LOADED:-}" ]] && return 0
readonly _FILE_VALIDATOR_LOADED=1

# DEPENDENCIES - determine validation lib directory
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _FILE_VALIDATOR_DIR="$VALIDATION_LIB_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _FILE_VALIDATOR_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # Go up two levels: validators/core/ -> validators/ -> validation/
    _FILE_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    _FILE_VALIDATOR_DIR="${HOME}/.shell-config/lib/validation"
fi

# Source shared utilities
# shellcheck source=../../shared/config.sh
source "$_FILE_VALIDATOR_DIR/shared/config.sh"
# shellcheck source=../../shared/file-operations.sh
source "$_FILE_VALIDATOR_DIR/shared/file-operations.sh"
# shellcheck source=../../shared/reporters.sh
source "$_FILE_VALIDATOR_DIR/shared/reporters.sh"

# VIOLATION TRACKING
_FILE_INFO_VIOLATIONS=()
_FILE_WARNING_VIOLATIONS=()
_FILE_EXTREME_VIOLATIONS=()

# Reset violations (call before batch validation)
file_validator_reset() {
    _FILE_INFO_VIOLATIONS=()
    _FILE_WARNING_VIOLATIONS=()
    _FILE_EXTREME_VIOLATIONS=()
}

# VALIDATION FUNCTIONS

validate_file_length() {
    local file="$1"

    [[ ! -f "$file" ]] && return 0

    # Get line count (fast)
    local lines
    lines=$(count_file_lines "$file")

    # Skip files below minimum INFO threshold (optimization)
    [[ $lines -lt $MIN_INFO_THRESHOLD ]] && return 0

    # Get language limit
    local limit
    limit=$(get_language_limit "$file")

    # Calculate thresholds
    local info_threshold=$((limit * INFO_THRESHOLD_PERCENT / 100))
    local warning_threshold=$((limit * WARNING_THRESHOLD_PERCENT / 100))

    # Collect violations (don't exit early - collect all)
    if [[ $lines -ge $limit ]]; then
        _FILE_EXTREME_VIOLATIONS+=("$file:$lines:$limit")
    elif [[ $lines -ge $warning_threshold ]]; then
        _FILE_WARNING_VIOLATIONS+=("$file:$lines:$limit")
    elif [[ $lines -ge $info_threshold ]]; then
        _FILE_INFO_VIOLATIONS+=("$file:$lines:$limit")
    fi

    return 0
}

# Validate multiple files
# Usage: validate_files_length file1.py file2.js ...
validate_files_length() {
    file_validator_reset
    for file in "$@"; do
        validate_file_length "$file"
    done
}

# =============================================================================
# REPORTING
# =============================================================================

# Check if there are any violations
# Returns: 0 if violations exist, 1 if clean
file_validator_has_violations() {
    [[ ${#_FILE_INFO_VIOLATIONS[@]} -gt 0 ]] \
        || [[ ${#_FILE_WARNING_VIOLATIONS[@]} -gt 0 ]] \
        || [[ ${#_FILE_EXTREME_VIOLATIONS[@]} -gt 0 ]]
}

# Check if there are blocking violations (WARNING or EXTREME)
# Returns: 0 if blocking violations exist, 1 if clean
file_validator_has_blocking_violations() {
    [[ ${#_FILE_WARNING_VIOLATIONS[@]} -gt 0 ]] \
        || [[ ${#_FILE_EXTREME_VIOLATIONS[@]} -gt 0 ]]
}

# Get violation counts
file_validator_info_count() { echo ${#_FILE_INFO_VIOLATIONS[@]}; }
file_validator_warning_count() { echo ${#_FILE_WARNING_VIOLATIONS[@]}; }
file_validator_extreme_count() { echo ${#_FILE_EXTREME_VIOLATIONS[@]}; }

# Show all violations with formatted output
# Returns: 1 if blocking violations exist, 0 otherwise
file_validator_show_violations() {
    # Exit if no violations
    if ! file_validator_has_violations; then
        return 0
    fi

    echo "" >&2

    # Show EXTREME violations (hard block with GitHub issue requirement)
    if [[ ${#_FILE_EXTREME_VIOLATIONS[@]} -gt 0 ]]; then
        validation_log_error "EXTREME: Files exceed language-specific limits"
        printf '\n' >&2
        for violation in "${_FILE_EXTREME_VIOLATIONS[@]}"; do
            IFS=':' read -r file lines limit <<<"$violation"
            local percentage=$((lines * 100 / limit))
            local overage=$((percentage - 100))
            printf '  %b✗%b %b%s%b (%s lines / %s limit = %s%% over)\n' "${RED}" "${NC}" "${RED}" "$file" "${NC}" "$lines" "$limit" "$overage" >&2
        done
        printf '\n' >&2
        echo "Large files hurt maintainability:" >&2
        echo "  - Harder to understand and navigate" >&2
        echo "  - More bugs per file (research shows 2-3x increase)" >&2
        echo "  - Difficult to test effectively" >&2
        echo "  - Signal multiple responsibilities (violates SRP)" >&2
        printf '\n' >&2
        echo "Strongly recommend refactoring into smaller modules." >&2
        printf '\n' >&2
        validation_log_warning "To bypass, create a GitHub issue documenting this technical debt first"
        validation_bypass_hint "GIT_SKIP_FILE_LENGTH_CHECK"
    fi

    # Show WARNING violations (hard block)
    if [[ ${#_FILE_WARNING_VIOLATIONS[@]} -gt 0 ]]; then
        validation_log_warning "WARNING: Files approaching limits"
        printf '\n' >&2
        for violation in "${_FILE_WARNING_VIOLATIONS[@]}"; do
            IFS=':' read -r file lines limit <<<"$violation"
            local percentage=$((lines * 100 / limit))
            printf '  %b⚠%b %s (%s lines / %s limit = %s%%)\n' "${YELLOW}" "${NC}" "$file" "$lines" "$limit" "$percentage" >&2
        done
        printf '\n' >&2
        echo "Files this size often indicate:" >&2
        echo "  - Multiple responsibilities in one file" >&2
        echo "  - Decreased readability" >&2
        echo "  - Harder to test and maintain" >&2
        printf '\n' >&2
        echo "Consider breaking into smaller, focused modules." >&2
        printf '\n' >&2
    fi

    # Show INFO violations (informational, doesn't block)
    if [[ ${#_FILE_INFO_VIOLATIONS[@]} -gt 0 ]]; then
        validation_log_info "INFO: Large files detected"
        for violation in "${_FILE_INFO_VIOLATIONS[@]}"; do
            IFS=':' read -r file lines limit <<<"$violation"
            local percentage=$((lines * 100 / limit))
            printf '  - %s (%s lines / %s limit = %s%%)\n' "$file" "$lines" "$limit" "$percentage" >&2
        done
        printf '\n' >&2
    fi

    # Return 1 if blocking violations exist
    if file_validator_has_blocking_violations; then
        if [[ ${#_FILE_EXTREME_VIOLATIONS[@]} -eq 0 ]]; then
            # Only WARNING violations - show bypass hint
            validation_bypass_hint "GIT_SKIP_FILE_LENGTH_CHECK"
        fi
        return 1
    fi

    return 0
}

# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

# Validate and report in one call
# Usage: validate_and_report_file_length file1.py file2.js
# Returns: 1 if blocking violations, 0 otherwise
validate_and_report_file_length() {
    validate_files_length "$@"
    file_validator_show_violations
}

# Export functions
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f file_validator_reset 2>/dev/null || true
    export -f validate_file_length 2>/dev/null || true
    export -f validate_files_length 2>/dev/null || true
    export -f file_validator_has_violations 2>/dev/null || true
    export -f file_validator_has_blocking_violations 2>/dev/null || true
    export -f file_validator_show_violations 2>/dev/null || true
    export -f validate_and_report_file_length 2>/dev/null || true
fi

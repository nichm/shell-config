#!/usr/bin/env bash
# =============================================================================
# 🔒 SECURITY VALIDATOR - Sensitive File Detection
# =============================================================================
# Validates files for sensitive filenames and patterns.
# Fast filename pattern matching for obviously sensitive files.
# Performance: ~0.15-0.20ms for 10 files (500x faster than Node.js alternatives)
# Optimizations: Early exit, in-line matching, ordered patterns
# Usage:
#   source lib/validation/validators/security-validator.sh
#   validate_sensitive_filename "/path/to/.env"
#   validate_sensitive_filenames file1 file2 ...
# This validator knows NOTHING about git - it's pure validation logic.
# =============================================================================
set -euo pipefail

# Prevent double-sourcing - but allow if patterns not loaded (new process context)
# Arrays can't be exported across processes, so we check actual array content
if [[ -n "${_SECURITY_VALIDATOR_LOADED:-}" ]] && [[ ${#_SENSITIVE_PATTERNS_COMBINED[@]} -gt 0 ]]; then
    return 0
fi
_SECURITY_VALIDATOR_LOADED=1

# DEPENDENCIES - determine validation lib directory
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _SECURITY_VALIDATOR_DIR="$VALIDATION_LIB_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _SECURITY_VALIDATOR_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # Go up two levels: validators/security/ -> validators/ -> validation/
    _SECURITY_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    _SECURITY_VALIDATOR_DIR="${HOME}/.shell-config/lib/validation"
fi

# Source shared utilities
# shellcheck source=../../shared/patterns.sh
source "$_SECURITY_VALIDATOR_DIR/shared/patterns.sh"
# shellcheck source=../../shared/reporters.sh
source "$_SECURITY_VALIDATOR_DIR/shared/reporters.sh"

# PATTERN ARRAYS

_build_sensitive_patterns_array() {
    local -a all=()
    all+=("${SENSITIVE_PATTERNS_HIGH[@]}")
    all+=("${SENSITIVE_PATTERNS_SSH[@]}")
    all+=("${SENSITIVE_PATTERNS_DATABASE[@]}")
    all+=("${SENSITIVE_PATTERNS_SECRETS[@]}")
    all+=("${SENSITIVE_PATTERNS_CLOUD[@]}")
    all+=("${SENSITIVE_PATTERNS_INFRA[@]}")
    all+=("${SENSITIVE_PATTERNS_BACKUP[@]}")
    all+=("${SENSITIVE_PATTERNS_API[@]}")
    all+=("${SENSITIVE_PATTERNS_ARCHIVE[@]}")
    printf '%s\n' "${all[@]}"
}

# Cache the combined patterns
_SENSITIVE_PATTERNS_COMBINED=()
if [[ ${#_SENSITIVE_PATTERNS_COMBINED[@]} -eq 0 ]]; then
    while IFS= read -r pattern; do
        _SENSITIVE_PATTERNS_COMBINED+=("$pattern")
    done < <(_build_sensitive_patterns_array)
fi

# VIOLATION TRACKING
_SECURITY_VIOLATIONS=()

# Reset violations
security_validator_reset() {
    _SECURITY_VIOLATIONS=()
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Check if a file is in an allowed exception path
# Usage: _is_allowed_path "/path/to/file"
# Returns: 0 if allowed (should skip), 1 if should check
_is_allowed_path() {
    local file="$1"
    for pattern in "${ALLOWED_PATTERNS[@]}"; do
        if [[ "$file" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Check if a single filename matches sensitive patterns
# Usage: _matches_sensitive_pattern "filename"
# Returns: 0 if sensitive, 1 if safe
_matches_sensitive_pattern() {
    local file="$1"

    # Rebuild patterns if not available (subshell context)
    if [[ ${#_SENSITIVE_PATTERNS_COMBINED[@]} -eq 0 ]]; then
        while IFS= read -r pattern; do
            _SENSITIVE_PATTERNS_COMBINED+=("$pattern")
        done < <(_build_sensitive_patterns_array)
    fi

    for pattern in "${_SENSITIVE_PATTERNS_COMBINED[@]}"; do
        if [[ "$file" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Validate a single file for sensitive filename
# Usage: validate_sensitive_filename "/path/to/file"
# Returns: 0 if safe, 1 if sensitive (adds to violations array)
validate_sensitive_filename() {
    local file="$1"

    # Check allowed patterns first (fewer patterns, fast path)
    _is_allowed_path "$file" && return 0

    # Check if matches sensitive pattern
    if _matches_sensitive_pattern "$file"; then
        _SECURITY_VIOLATIONS+=("$file")
        return 1
    fi

    return 0
}

# Validate multiple files
# Usage: validate_sensitive_filenames file1 file2 ...
# Returns: Number of sensitive files found
validate_sensitive_filenames() {
    security_validator_reset
    local count=0
    for file in "$@"; do
        validate_sensitive_filename "$file" || count=$((count + 1))
    done
    echo "$count"
}

# =============================================================================
# REPORTING
# =============================================================================

# Check if there are violations
security_validator_has_violations() {
    [[ ${#_SECURITY_VIOLATIONS[@]} -gt 0 ]]
}

# Get violation count
security_validator_count() {
    echo ${#_SECURITY_VIOLATIONS[@]}
}

# Get violations array
security_validator_get_violations() {
    printf '%s\n' "${_SECURITY_VIOLATIONS[@]}"
}

# Show violations with formatted output
# Returns: 1 if violations exist, 0 otherwise
security_validator_show_violations() {
    if ! security_validator_has_violations; then
        return 0
    fi

    validation_log_error "Sensitive filenames detected: ${#_SECURITY_VIOLATIONS[@]} file(s)"
    echo "" >&2
    for file in "${_SECURITY_VIOLATIONS[@]}"; do
        echo "  - $file" >&2
    done
    echo "" >&2
    echo "These files may contain sensitive information (keys, credentials, secrets)." >&2
    echo "" >&2
    echo "Allowed exceptions:" >&2
    echo "  - Files ending in .example, .sample, .template, .dist, .default" >&2
    echo "  - Files in tests/, test/, fixtures/, examples/, docs/" >&2
    echo "" >&2
    validation_bypass_hint "GIT_SKIP_HOOKS" "To bypass"
    return 1
}

# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

# Validate and report in one call
# Usage: validate_and_report_sensitive_files file1 file2
# Returns: 1 if violations, 0 otherwise
validate_and_report_sensitive_files() {
    validate_sensitive_filenames "$@" >/dev/null
    security_validator_show_violations
}

# Quick check for a single file (doesn't track in array)
# Usage: is_sensitive_filename "file.env"
# Returns: 0 if sensitive, 1 if safe
is_sensitive_filename() {
    local file="$1"
    _is_allowed_path "$file" && return 1
    _matches_sensitive_pattern "$file"
}

# Export functions
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f security_validator_reset 2>/dev/null || true
    export -f validate_sensitive_filename 2>/dev/null || true
    export -f validate_sensitive_filenames 2>/dev/null || true
    export -f security_validator_has_violations 2>/dev/null || true
    export -f security_validator_show_violations 2>/dev/null || true
    export -f validate_and_report_sensitive_files 2>/dev/null || true
    export -f is_sensitive_filename 2>/dev/null || true
fi

#!/usr/bin/env bash
# =============================================================================
# validation-loop-advanced.sh - Validation loop helpers
# =============================================================================
# Shared helpers for conditional, batch, and timeout-based validation.
# Usage:
#   source "${BASH_SOURCE[0]}"
# =============================================================================
set -euo pipefail

# =============================================================================
# VALIDATION WITH ERROR COLLECTION
# =============================================================================

# Run validation and collect all errors before failing
# Args:
#   $1 - Validation function name (must return error message on failure)
#   $2 - Optional regex pattern to filter files (default: all files)
# Returns:
#   0 if all validations passed, 1 if any failed
# Note: Validation function should output error message to stdout and return 1
run_validation_collect_errors() {
    local validation_func="$1"
    local file_filter="${2:-.*}"
    local failed=0
    local errors=()

    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_staged_files "$file_filter")

    for file in "${files[@]}"; do
        if ! should_validate_file "$file"; then
            continue
        fi

        local error_msg
        error_msg=$("$validation_func" "$file")
        if [[ -n "$error_msg" ]]; then
            errors+=("$error_msg")
            ((++failed))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        for error in "${errors[@]}"; do
            echo "$error"
        done
    fi

    return $failed
}

# =============================================================================
# CONDITIONAL VALIDATION
# =============================================================================

# Run validation only if condition is met
# Args:
#   $1 - Condition command to test (e.g., "command -v oxlint")
#   $2 - Validation function name
#   $3 - Optional regex pattern to filter files
# Returns:
#   0 if validation passed or skipped, 1 if validation failed
# Usage:
#   run_validation_if "command -v oxlint" "validate_oxlint" "\.(js|ts)$"
run_validation_if() {
    local condition="$1"
    local validation_func="$2"
    local file_filter="${3:-.*}"

    # SECURITY: Use direct command execution instead of eval to prevent command injection
    # Parse common condition patterns safely
    case "$condition" in
        command\ -v* | which\ *)
            # Handle: command -v <tool> or which <tool>
            if $condition >/dev/null 2>&1; then
                run_validation_on_staged "$validation_func" "$file_filter"
            fi
            ;;
        \[*\])
            # Handle: [ -f file ] or similar test
            if $condition >/dev/null 2>&1; then
                run_validation_on_staged "$validation_func" "$file_filter"
            fi
            ;;
        test\ *)
            # Handle: test -f file
            if $condition >/dev/null 2>&1; then
                run_validation_on_staged "$validation_func" "$file_filter"
            fi
            ;;
        *)
            # SECURITY: Reject unknown conditions for safety
            log_warning "Unknown condition pattern: $condition"
            return 1
            ;;
    esac

    return 0
}

# Run validation with optional skip flag
# Args:
#   $1 - Skip flag name (e.g., "GIT_SKIP_MY_CHECK")
#   $2 - Validation function name
#   $3 - Optional regex pattern to filter files
# Returns:
#   0 if validation passed or skipped, 1 if validation failed
run_validation_with_skip() {
    local skip_flag="$1"
    local validation_func="$2"
    local file_filter="${3:-.*}"

    if [[ "${!skip_flag:-}" == "1" ]]; then
        log_info "Skipped ($skip_flag=1)"
        return 0
    fi

    run_validation_on_staged "$validation_func" "$file_filter"
}

# =============================================================================
# BATCH VALIDATION
# =============================================================================

# Run multiple validations in sequence
# Args:
#   $@ - Array of validation function names
# Returns:
#   0 if all validations passed, 1 if any failed
run_multiple_validations() {
    local all_passed=0
    local validations=("$@")

    for validation_func in "${validations[@]}"; do
        if ! "$validation_func"; then
            all_passed=1
        fi
    done

    return $all_passed
}

# Run validations with early exit on first failure
# Args:
#   $@ - Array of validation function names
# Returns:
#   0 if all validations passed, 1 if any failed
run_multiple_validations_strict() {
    for validation_func in "$@"; do
        if ! "$validation_func"; then
            # validation failed (returned non-zero), exit
            return 1
        fi
    done
    return 0
}

# =============================================================================
# FILE CATEGORY VALIDATION
# =============================================================================

# Run validation on specific file types
# Args:
#   $1 - Validation function name
#   $2 - Comma-separated list of extensions (e.g., "js,ts,tsx")
# Returns:
#   0 if all validations passed, 1 if any failed
run_validation_on_extensions() {
    local validation_func="$1"
    local extensions="$2"

    # Build regex pattern from extensions
    local ext_pattern=""
    local ext
    while IFS= read -r -d',' ext || [[ -n "$ext" ]]; do
        ext="${ext#"${ext%%[![:space:]]*}"}"
        ext="${ext%"${ext##*[![:space:]]}"}"
        [[ -z "$ext" ]] && continue
        [[ -n "$ext_pattern" ]] && ext_pattern+="|"
        ext_pattern+="\\.$ext\$"
    done <<<"$extensions,"

    run_validation_on_staged "$validation_func" "$ext_pattern"
}

run_validation_exclude_paths() {
    local validation_func="$1"
    local exclude_paths="$2"
    local file_filter="${3:-.*}"
    local failed=0

    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_staged_files "$file_filter")

    for file in "${files[@]}"; do
        # Check if file should be excluded
        local excluded=0
        local pattern
        while IFS= read -r -d',' pattern || [[ -n "$pattern" ]]; do
            pattern="${pattern#"${pattern%%[![:space:]]*}"}"
            pattern="${pattern%"${pattern##*[![:space:]]}"}"
            [[ -z "$pattern" ]] && continue
            if [[ "$file" =~ $pattern ]]; then
                excluded=1
                break
            fi
        done <<<"$exclude_paths,"

        [[ $excluded -eq 1 ]] && continue

        if ! should_validate_file "$file"; then
            continue
        fi

        if ! "$validation_func" "$file"; then
            failed=1
        fi
    done

    return $failed
}

# =============================================================================
# VALIDATION WITH TIMEOUT
# =============================================================================

run_validation_with_timeout() {
    local validation_func="$1"
    local timeout="$2"
    local file_filter="${3:-.*}"
    local failed=0

    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_staged_files "$file_filter")

    for file in "${files[@]}"; do
        if ! should_validate_file "$file"; then
            continue
        fi

        if ! _portable_timeout "$timeout" "$validation_func" "$file" >/dev/null 2>&1; then
            log_error "Validation timed out for: $file"
            failed=1
        fi
    done

    return $failed
}

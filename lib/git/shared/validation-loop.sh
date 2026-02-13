#!/usr/bin/env bash
# =============================================================================
# 🔄 VALIDATION LOOP - Shared Validation Orchestration
# =============================================================================
# Provides standardized validation loop patterns for git hooks.
# Handles file iteration, error tracking, and performance optimization.
# NOTE: Sequential execution by design for use in secondary hooks
# (pre-push, pre-merge-commit). The main pre-commit hook already uses
# parallel execution - see lib/git/stages/commit/pre-commit.sh lines 82-254.
# See docs/decisions/PARALLEL-ARCHITECTURE.md for details.
# Usage:
#   source "${HOOKS_DIR}/shared/validation-loop.sh"
#   run_validation_on_staged "validate_function" "\.sh$" || exit 1
# =============================================================================
set -euo pipefail

# Source from validation module (single source of truth)
VALIDATION_LOOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_SHARED_DIR="${VALIDATION_LOOP_DIR}/../../validation/shared"

# Source command cache for command_exists (used by timeout-wrapper and fallback)
if ! declare -f command_exists &>/dev/null; then
    # shellcheck source=../../core/command-cache.sh
    [[ -f "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/command-cache.sh" ]] &&
        source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/command-cache.sh"
fi
if ! declare -f command_exists &>/dev/null; then
    command_exists() { command -v "$1" >/dev/null 2>&1; }
fi

# shellcheck source=../../validation/shared/file-operations.sh
source "${VALIDATION_SHARED_DIR}/file-operations.sh"
# shellcheck source=../../../validation/shared/reporters.sh
source "${VALIDATION_SHARED_DIR}/reporters.sh"

# Source portable timeout wrapper (for cross-platform compatibility)
if [[ -f "${VALIDATION_LOOP_DIR}/timeout-wrapper.sh" ]]; then
    # shellcheck source=timeout-wrapper.sh
    source "${VALIDATION_LOOP_DIR}/timeout-wrapper.sh"
else
    # Fallback: define minimal portable timeout (sources command-cache if available)
    _portable_timeout() {
        local timeout_seconds="$1"
        shift
        if command_exists "timeout" 2>/dev/null; then
            timeout "$timeout_seconds" "$@"
        elif command_exists "gtimeout" 2>/dev/null; then
            gtimeout "$timeout_seconds" "$@"
        else
            # No timeout available - run without protection
            if [[ -n "${GIT_HOOKS_DEBUG:-}" ]]; then
                echo "⚠️  Timeout unavailable - command may run indefinitely" >&2
            fi
            "$@"
        fi
    }
fi

# shellcheck source=validation-loop-advanced.sh
source "${VALIDATION_LOOP_DIR}/validation-loop-advanced.sh"

# =============================================================================
# VALIDATION ORCHESTRATION
# =============================================================================

# Run validation function on all staged files
# Args:
#   $1 - Validation function name (must accept file path as argument)
#   $2 - Optional regex pattern to filter files (default: all files)
# Returns:
#   0 if all validations passed, 1 if any failed
# Usage:
#   validate_file() {
#     local file="$1"
#     # validation logic
#     return 0 # or 1 if failed
#   }
#   run_validation_on_staged "validate_file" "\.sh$"
run_validation_on_staged() {
    local validation_func="$1"
    local file_filter="${2:-.*}"
    local failed=0
    local passed=0
    local skipped=0
    local total=0

    # Get files as array (safe for spaces)
    local OLDIFS="$IFS"
    IFS=$'\n'
    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_staged_files "$file_filter")
    IFS="$OLDIFS"

    local total=${#files[@]}

    if [[ $total -eq 0 ]]; then
        return 0
    fi

    # Run validation on each file
    for file in "${files[@]}"; do
        if ! should_validate_file "$file"; then
            ((++skipped))
            continue
        fi

        if "$validation_func" "$file"; then
            ((++passed))
        else
            ((++failed))
        fi
    done

    # Report summary
    [[ $total -gt 0 ]] && report_check_summary "Validation" "$passed" "$failed" "$skipped"

    return $failed
}

# Run validation function on all git-tracked files
# Args:
#   $1 - Validation function name
#   $2 - Optional regex pattern to filter files (default: all files)
# Returns:
#   0 if all validations passed, 1 if any failed
run_validation_on_all() {
    local validation_func="$1"
    local file_filter="${2:-.*}"
    local failed=0
    local passed=0
    local skipped=0

    local OLDIFS="$IFS"
    IFS=$'\n'
    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_all_files "$file_filter")
    IFS="$OLDIFS"

    local total=${#files[@]}

    if [[ $total -eq 0 ]]; then
        return 0
    fi

    for file in "${files[@]}"; do
        if ! should_validate_file "$file"; then
            ((++skipped))
            continue
        fi

        if "$validation_func" "$file"; then
            ((++passed))
        else
            ((++failed))
        fi
    done

    [[ $total -gt 0 ]] && report_check_summary "Validation" "$passed" "$failed" "$skipped"

    return $failed
}

# Run validation function on files in commit range
# Args:
#   $1 - Validation function name
#   $2 - Commit range (e.g., "origin/main..HEAD")
#   $3 - Optional regex pattern to filter files (default: all files)
# Returns:
#   0 if all validations passed, 1 if any failed
run_validation_on_range() {
    local validation_func="$1"
    local commit_range="$2"
    local file_filter="${3:-.*}"
    local failed=0
    local passed=0
    local skipped=0

    local OLDIFS="$IFS"
    IFS=$'\n'
    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_range_files "$commit_range" | grep -E "$file_filter" || true)
    IFS="$OLDIFS"

    local total=${#files[@]}

    if [[ $total -eq 0 ]]; then
        return 0
    fi

    for file in "${files[@]}"; do
        if ! should_validate_file "$file"; then
            ((++skipped))
            continue
        fi

        if "$validation_func" "$file"; then
            ((++passed))
        else
            ((++failed))
        fi
    done

    [[ $total -gt 0 ]] && report_check_summary "Validation" "$passed" "$failed" "$skipped"

    return $failed
}

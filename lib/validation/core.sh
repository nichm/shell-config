#!/usr/bin/env bash
# =============================================================================
# 🎯 VALIDATION CORE - Unified Validation Engine
# =============================================================================
# Central orchestrator for all validation functions.
# Provides a unified API for syntax, security, file, and workflow validation.
# Usage:
#   source lib/validation/core.sh
#   # Individual validators
#   validate_syntax file.py
#   validate_file_length file.py
#   validate_sensitive_filename .env
#   validate_workflow .github/workflows/ci.yml
#   # Batch validation
#   validate_all file1.py file2.sh
#   validate_staged_files
#   # Auto-detect and validate
#   validate_file file.py  # Runs appropriate validators
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_VALIDATION_CORE_LOADED:-}" ]] && return 0
readonly _VALIDATION_CORE_LOADED=1

# FIND VALIDATION MODULE ROOT
if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _VALIDATION_CORE_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _VALIDATION_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    _VALIDATION_CORE_DIR="${HOME}/.shell-config/lib/validation"
fi

# LOAD SHARED UTILITIES
# shellcheck source=shared/patterns.sh
source "$_VALIDATION_CORE_DIR/shared/patterns.sh"
# shellcheck source=shared/config.sh
source "$_VALIDATION_CORE_DIR/shared/config.sh"
# shellcheck source=shared/file-operations.sh
source "$_VALIDATION_CORE_DIR/shared/file-operations.sh"
# shellcheck source=shared/reporters.sh
source "$_VALIDATION_CORE_DIR/shared/reporters.sh"

# LOAD VALIDATORS
# shellcheck source=validators/core/file-validator.sh
source "$_VALIDATION_CORE_DIR/validators/core/file-validator.sh"
# shellcheck source=validators/security/security-validator.sh
source "$_VALIDATION_CORE_DIR/validators/security/security-validator.sh"
# shellcheck source=validators/core/syntax-validator.sh
source "$_VALIDATION_CORE_DIR/validators/core/syntax-validator.sh"
# shellcheck source=validators/infra/workflow-validator.sh
source "$_VALIDATION_CORE_DIR/validators/infra/workflow-validator.sh"
# shellcheck source=validators/infra/infra-validator.sh
source "$_VALIDATION_CORE_DIR/validators/infra/infra-validator.sh"
# shellcheck source=validators/security/phantom-validator.sh
source "$_VALIDATION_CORE_DIR/validators/security/phantom-validator.sh"

# UNIFIED API

validation_reset_all() {
    file_validator_reset
    security_validator_reset
    syntax_validator_reset
    workflow_validator_reset
    infra_validator_reset
    phantom_validator_reset
}

# AUTO-DETECT VALIDATION

# Validate a single file with appropriate validators
validate_file() {
    local file="$1"
    local errors=0

    [[ ! -f "$file" ]] && return 0

    # Always check file length (violations tracked in arrays)
    # Save current counts to detect if this file added violations
    local warning_before=${#_FILE_WARNING_VIOLATIONS[@]}
    local extreme_before=${#_FILE_EXTREME_VIOLATIONS[@]}
    validate_file_length "$file"
    local warning_after=${#_FILE_WARNING_VIOLATIONS[@]}
    local extreme_after=${#_FILE_EXTREME_VIOLATIONS[@]}

    # Check if this file added any blocking violations
    if [[ $warning_after -gt $warning_before ]] || [[ $extreme_after -gt $extreme_before ]]; then
        errors=$((errors + 1))
    fi

    # Always check for sensitive filenames
    validate_sensitive_filename "$file" || errors=$((errors + 1))

    # Run syntax validation for supported types
    validate_syntax "$file" || errors=$((errors + 1))

    # Run workflow validation for GitHub Actions files
    if is_github_workflow "$file"; then
        validate_workflow_quick "$file" || errors=$((errors + 1))
    fi

    return $((errors > 0 ? 1 : 0))
}

validate_files() {
    validation_reset_all
    local errors=0

    for file in "$@"; do
        validate_file "$file" || errors=$((errors + 1))
    done

    return $((errors > 0 ? 1 : 0))
}

# STAGED FILES VALIDATION (Git Integration)

validate_staged_files() {
    validation_reset_all

    local files=()
    local file
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_staged_files)

    [[ ${#files[@]} -eq 0 ]] && return 0

    # Run all validations
    for file in "${files[@]}"; do
        [[ -f "$file" ]] && validate_file "$file"
    done

    # Check for blocking violations
    local has_errors=0

    if file_validator_has_blocking_violations; then
        has_errors=1
    fi

    if security_validator_has_violations; then
        has_errors=1
    fi

    if syntax_validator_has_errors; then
        has_errors=1
    fi

    if workflow_validator_has_errors; then
        has_errors=1
    fi

    return $has_errors
}

validate_and_report_staged_files() {
    local result=0
    validate_staged_files || result=$?

    # Show all reports
    file_validator_show_violations
    security_validator_show_violations
    syntax_validator_show_errors
    workflow_validator_show_results

    return $result
}

# CATEGORY-SPECIFIC VALIDATION

validate_all_syntax() {
    syntax_validator_reset
    validate_files_syntax "$@"
    syntax_validator_show_errors
}

validate_all_security() {
    security_validator_reset
    validate_sensitive_filenames "$@" >/dev/null
    security_validator_show_violations
}

validate_all_file_lengths() {
    file_validator_reset
    validate_files_length "$@"
    file_validator_show_violations
}

validate_all_workflows() {
    workflow_validator_reset
    validate_workflows "$@"
    workflow_validator_show_results
}

# DIRECTORY VALIDATION

validate_directory() {
    local dir="$1"
    local pattern="${2:-*}"

    [[ ! -d "$dir" ]] && return 1

    validation_reset_all

    local file
    while IFS= read -r file; do
        [[ -f "$file" ]] && validate_file "$file"
    done < <(find "$dir" -type f -name "$pattern" 2>/dev/null)
}

validate_repo_workflows() {
    local repo_root="${1:-$(find_repo_root "$(pwd)")}"
    local workflow_dir="$repo_root/.github/workflows"

    [[ ! -d "$workflow_dir" ]] && return 0

    validate_workflows_in_dir "$workflow_dir"
    workflow_validator_show_results
}

# BACKWARDS COMPATIBILITY

_validate_staged_files() {
    validate_staged_syntax
    syntax_validator_show_errors
}

check_file_length() {
    validate_file_length "$@"
}

check_sensitive_filenames() {
    security_validator_reset
    local file
    while IFS= read -r file; do
        [[ -n "$file" ]] && validate_sensitive_filename "$file"
    done < <(get_staged_files)
    security_validator_show_violations
}

gha_validate() {
    validate_repo_workflows "$@"
}

# STATUS FUNCTIONS

validation_has_issues() {
    file_validator_has_violations \
        || security_validator_has_violations \
        || syntax_validator_has_errors \
        || workflow_validator_has_errors \
        || infra_validator_has_errors
}

validation_has_blocking_issues() {
    file_validator_has_blocking_violations \
        || security_validator_has_violations \
        || syntax_validator_has_errors \
        || workflow_validator_has_errors \
        || infra_validator_has_errors
}

validation_summary() {
    echo "" >&2
    validation_header "Validation Summary"

    echo "  File Length:" >&2
    echo "    - Info:     $(file_validator_info_count)" >&2
    echo "    - Warnings: $(file_validator_warning_count)" >&2
    echo "    - Extreme:  $(file_validator_extreme_count)" >&2

    echo "  Security:     $(security_validator_count) sensitive file(s)" >&2
    echo "  Syntax:       $(syntax_validator_error_count) error(s)" >&2
    echo "  Workflows:    $(workflow_validator_error_count) error(s), $(workflow_validator_warning_count) warning(s)" >&2
    echo "  Infra:        $(infra_validator_error_count) error(s)" >&2
    echo "" >&2

    if validation_has_blocking_issues; then
        validation_log_error "Blocking issues found"
        return 1
    else
        validation_log_success "All validations passed"
        return 0
    fi
}

# EXPORTS
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f validation_reset_all 2>/dev/null || true
    export -f validate_file 2>/dev/null || true
    export -f validate_files 2>/dev/null || true
    export -f validate_staged_files 2>/dev/null || true
    export -f validate_and_report_staged_files 2>/dev/null || true
    export -f validate_all_syntax 2>/dev/null || true
    export -f validate_all_security 2>/dev/null || true
    export -f validate_all_file_lengths 2>/dev/null || true
    export -f validate_all_workflows 2>/dev/null || true
    export -f validate_directory 2>/dev/null || true
    export -f validate_repo_workflows 2>/dev/null || true
    export -f validation_has_issues 2>/dev/null || true
    export -f validation_has_blocking_issues 2>/dev/null || true
    export -f validation_summary 2>/dev/null || true
fi

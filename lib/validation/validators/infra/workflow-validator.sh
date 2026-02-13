#!/usr/bin/env bash
# =============================================================================
# 🔒 WORKFLOW VALIDATOR - GitHub Actions Security Validation
# =============================================================================
# Security-focused validation for GitHub Actions workflows.
# Uses multiple scanning engines: actionlint, zizmor, poutine, octoscan
# Usage:
#   source lib/validation/validators/workflow-validator.sh
#   validate_workflow "/path/to/workflow.yml"
#   validate_workflows_in_dir "/path/to/.github/workflows"
# This validator knows NOTHING about git - it's pure validation logic.
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_WORKFLOW_VALIDATOR_LOADED:-}" ]] && return 0
readonly _WORKFLOW_VALIDATOR_LOADED=1

# DEPENDENCIES - determine validation lib directory
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _WORKFLOW_VALIDATOR_DIR="$VALIDATION_LIB_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _WORKFLOW_VALIDATOR_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # Go up two levels: validators/infra/ -> validators/ -> validation/
    _WORKFLOW_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    _WORKFLOW_VALIDATOR_DIR="${HOME}/.shell-config/lib/validation"
fi

# Source shared utilities
# shellcheck source=../../shared/file-operations.sh
source "$_WORKFLOW_VALIDATOR_DIR/shared/file-operations.sh"
# shellcheck source=../../shared/reporters.sh
source "$_WORKFLOW_VALIDATOR_DIR/shared/reporters.sh"
# shellcheck source=../../shared/workflow-scanners.sh
source "$_WORKFLOW_VALIDATOR_DIR/shared/workflow-scanners.sh"

# CONFIGURATION
WORKFLOW_SCAN_VERBOSE="${WORKFLOW_SCAN_VERBOSE:-0}"
WORKFLOW_SCAN_MODE="${WORKFLOW_SCAN_MODE:-default}" # quick, default, all

# TOOL DETECTION: Use _wf_check_tool, _wf_get_tool_path, _wf_get_version
# from workflow-scanners.sh directly (no wrappers needed)

# COUNTERS
_WORKFLOW_TOTAL_ERRORS=0
_WORKFLOW_TOTAL_WARNINGS=0

workflow_validator_reset() {
    _WORKFLOW_TOTAL_ERRORS=0
    _WORKFLOW_TOTAL_WARNINGS=0
}

# SCANNER FUNCTIONS

_run_actionlint() {
    local file="$1"
    local repo_root="${2:-$(find_repo_root "$(dirname "$file")")}"

    local error_count=0
    local exit_code=0
    _wf_run_actionlint "$file" "$repo_root" error_count || exit_code=$?

    _WORKFLOW_TOTAL_ERRORS=$((_WORKFLOW_TOTAL_ERRORS + error_count))
    return $exit_code
}

# Run zizmor security scanner (delegates to shared scanner)
_run_zizmor() {
    local file="$1"
    local repo_root="${2:-$(find_repo_root "$(dirname "$file")")}"

    local findings=0
    local result exit_code=0
    result=$(_wf_run_zizmor "$file" "$repo_root" findings 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 && $findings -gt 0 ]]; then
        # Check actual output for high-severity issues using bash native regex
        if [[ "$result" =~ high ]]; then
            _WORKFLOW_TOTAL_ERRORS=$((_WORKFLOW_TOTAL_ERRORS + findings))
        else
            _WORKFLOW_TOTAL_WARNINGS=$((_WORKFLOW_TOTAL_WARNINGS + findings))
        fi
    fi
    return $exit_code
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate a single workflow file
# Usage: validate_workflow "/path/to/workflow.yml"
# Returns: 0 if valid, 1 if errors
validate_workflow() {
    local file="$1"
    local mode="${2:-$WORKFLOW_SCAN_MODE}"

    [[ ! -f "$file" ]] && return 0

    # Verify it's a workflow file
    if ! is_github_workflow "$file"; then
        return 0
    fi

    local repo_root
    repo_root=$(find_repo_root "$(dirname "$file")")

    case "$mode" in
        quick)
            # Quick: actionlint only
            _run_actionlint "$file" "$repo_root"
            ;;
        all)
            # Full: all scanners
            _run_actionlint "$file" "$repo_root"
            _run_zizmor "$file" "$repo_root"
            ;;
        *)
            # Default: actionlint + zizmor
            _run_actionlint "$file" "$repo_root"
            _run_zizmor "$file" "$repo_root"
            ;;
    esac
}

# Validate all workflows in a directory
# Usage: validate_workflows_in_dir "/path/to/.github/workflows"
validate_workflows_in_dir() {
    local dir="$1"
    local mode="${2:-$WORKFLOW_SCAN_MODE}"

    [[ ! -d "$dir" ]] && return 0

    workflow_validator_reset

    local file
    while IFS= read -r file; do
        validate_workflow "$file" "$mode"
    done < <(find "$dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null)
}

# Validate workflow files from a list
# Usage: validate_workflows file1.yml file2.yml ...
validate_workflows() {
    workflow_validator_reset
    for file in "$@"; do
        validate_workflow "$file"
    done
}

# =============================================================================
# REPORTING
# =============================================================================

workflow_validator_has_errors() {
    [[ $_WORKFLOW_TOTAL_ERRORS -gt 0 ]]
}

workflow_validator_has_warnings() {
    [[ $_WORKFLOW_TOTAL_WARNINGS -gt 0 ]]
}

workflow_validator_error_count() {
    echo "$_WORKFLOW_TOTAL_ERRORS"
}

workflow_validator_warning_count() {
    echo "$_WORKFLOW_TOTAL_WARNINGS"
}

# Show validation results
workflow_validator_show_results() {
    if [[ "$_WORKFLOW_TOTAL_ERRORS" -gt 0 ]]; then
        validation_log_error "Workflow validation found $_WORKFLOW_TOTAL_ERRORS error(s)"
        return 1
    elif [[ "$_WORKFLOW_TOTAL_WARNINGS" -gt 0 ]]; then
        validation_log_warning "Workflow validation found $_WORKFLOW_TOTAL_WARNINGS warning(s)"
        return 0
    else
        validation_log_success "All workflows passed security validation"
        return 0
    fi
}

# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

# Quick validation for pre-commit (actionlint only)
# Usage: validate_workflow_quick "/path/to/workflow.yml"
validate_workflow_quick() {
    local file="$1"
    validate_workflow "$file" "quick"
}

# Full security scan
# Usage: validate_workflow_full "/path/to/workflow.yml"
validate_workflow_full() {
    local file="$1"
    validate_workflow "$file" "all"
}

# Export functions
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f workflow_validator_reset 2>/dev/null || true
    export -f validate_workflow 2>/dev/null || true
    export -f validate_workflows 2>/dev/null || true
    export -f validate_workflows_in_dir 2>/dev/null || true
    export -f workflow_validator_has_errors 2>/dev/null || true
    export -f workflow_validator_show_results 2>/dev/null || true
    export -f validate_workflow_quick 2>/dev/null || true
    export -f validate_workflow_full 2>/dev/null || true
fi

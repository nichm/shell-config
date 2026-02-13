#!/usr/bin/env bash
# =============================================================================
# 🔌 VALIDATOR API - Unified External Interface
# =============================================================================
# Pure validation logic separated from git orchestration.
# Enables reuse by Git hooks, CLI tools, AI agents, and CI/CD systems.
# Features:
# - JSON output mode for AI/CI integration
# - Parallel execution for batch validation
# - Works without git context
# - Standardized exit codes and result formatting
# Usage:
#   source lib/validators/api.sh
#   # Console output (default)
#   validator_api_run file1.py file2.sh
#   # JSON output for AI/CI
#   VALIDATOR_OUTPUT=json validator_api_run file1.py
#   # Parallel execution
#   VALIDATOR_PARALLEL=4 validator_api_run file1.py file2.js file3.sh
#   # Custom output file
#   VALIDATOR_OUTPUT_FILE=results.json validator_api_run file1.py
# Exit Codes:
#   0 - All validations passed
#   1 - One or more validations failed
#   2 - Error in API execution (missing deps, invalid args)
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_VALIDATOR_API_LOADED:-}" ]] && return 0
readonly _VALIDATOR_API_LOADED=1

# =============================================================================
# CONSTANTS
# =============================================================================

readonly VALIDATOR_API_VERSION="1.0.0"
export VALIDATOR_API_VERSION

# =============================================================================
# FIND VALIDATION MODULE ROOT
# =============================================================================

# Get script directory (bash/zsh compatible)
if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _VALIDATOR_API_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _VALIDATOR_API_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    _VALIDATOR_API_DIR="${HOME}/.shell-config/lib/validation"
fi

# =============================================================================
# LOAD SPLIT MODULES
# =============================================================================

# shellcheck source=core.sh
source "$_VALIDATOR_API_DIR/core.sh"
# shellcheck source=api-internal.sh
source "$_VALIDATOR_API_DIR/api-internal.sh"
# shellcheck source=api-parallel.sh
source "$_VALIDATOR_API_DIR/api-parallel.sh"
# shellcheck source=api-output.sh
source "$_VALIDATOR_API_DIR/api-output.sh"
# shellcheck source=api-public.sh
source "$_VALIDATOR_API_DIR/api-public.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

# Output format: console, json
VALIDATOR_OUTPUT="${VALIDATOR_OUTPUT:-console}"

# Parallel jobs (0 = sequential, 1+ = parallel)
VALIDATOR_PARALLEL="${VALIDATOR_PARALLEL:-0}"

# Output file for JSON results (optional)
VALIDATOR_OUTPUT_FILE="${VALIDATOR_OUTPUT_FILE:-}"

# =============================================================================
# MAIN API
# =============================================================================

# Run validation on files
# Usage: validator_api_run file1 [file2 file3 ...]
# Returns: 0 if all pass, 1 if any fail, 2 on error
validator_api_run() {
    [[ $# -eq 0 ]] && {
        echo "Usage: validator_api_run file1 [file2 ...]" >&2
        return 2
    }

    # Validate environment variables
    _validator_api_validate_env || return $?

    _validator_api_init

    local files=("$@")

    # Validate files
    if [[ "$VALIDATOR_PARALLEL" -gt 0 ]] && [[ ${#files[@]} -gt 1 ]]; then
        _validator_validate_parallel "${files[@]}"
    else
        for file in "${files[@]}"; do
            _validator_validate_file "$file"
        done
    fi

    # Output results
    local exit_code=0

    case "$VALIDATOR_OUTPUT" in
        json)
            _validator_api_print_json
            # Check for failures
            validator_api_status || exit_code=1
            ;;
        console | *)
            _validator_api_print_console
            exit_code=$?
            ;;
    esac

    return $exit_code
}

# Public helper functions live in api-public.sh

# =============================================================================
# EXPORTS
# =============================================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f validator_api_run 2>/dev/null || true
    export -f validator_api_validate_staged 2>/dev/null || true
    export -f validator_api_validate_dir 2>/dev/null || true
    export -f validator_api_status 2>/dev/null || true
    export -f validator_api_get_results 2>/dev/null || true
    export -f validator_api_version 2>/dev/null || true
    export -f validator_api_help 2>/dev/null || true
fi

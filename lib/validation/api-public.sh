#!/usr/bin/env bash
# =============================================================================
# 🔌 VALIDATOR API - Public Helpers
# =============================================================================
# Public helper functions for the validation API.
# Usage:
#   source "$SHELL_CONFIG_DIR/lib/validation/api-public.sh"
# =============================================================================
set -euo pipefail

# Validate all staged git files
# Usage: validator_api_validate_staged
validator_api_validate_staged() {
    local files=()
    local file

    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_staged_files 2>/dev/null || true)

    [[ ${#files[@]} -eq 0 ]] && return 0

    validator_api_run "${files[@]}"
}

# Validate all files in a directory
# Usage: validator_api_validate_dir "/path/to/dir" ["pattern"]
validator_api_validate_dir() {
    local dir="$1"
    local pattern="${2:-*}"
    local files=()

    [[ ! -d "$dir" ]] && {
        echo "Error: Directory not found: $dir" >&2
        return 2
    }

    while IFS= read -r file; do
        [[ -f "$file" ]] && files+=("$file")
    done < <(find "$dir" -type f -name "$pattern" 2>/dev/null)

    [[ ${#files[@]} -eq 0 ]] && return 0

    validator_api_run "${files[@]}"
}

# Get validation results as JSON (without running validation)
# Usage: validator_api_get_results
validator_api_get_results() {
    _validator_api_build_json
    printf '%s\n' "$_VALIDATOR_API_JSON_OUTPUT"
}

# Get simple pass/fail status
# Usage: validator_api_status
# Returns: 0 if all pass, 1 if any fail
validator_api_status() {
    local file result
    for file in "${_VALIDATOR_FILES[@]}"; do
        result=$(_validator_get_result "$file")
        [[ "$result" == "fail" ]] && return 1
    done
    return 0
}

# Show API version
validator_api_version() {
    echo "Validator API v${VALIDATOR_API_VERSION}"
}

# Show API usage
validator_api_help() {
    cat <<'EOT'
Validator API - Unified Validation Interface

USAGE:
  source lib/validators/api.sh
  validator_api_run file1 [file2 ...]

MODES:
  VALIDATOR_OUTPUT=console   Console output (default)
  VALIDATOR_OUTPUT=json      JSON output for AI/CI

PARALLEL:
  VALIDATOR_PARALLEL=0       Sequential (default)
  VALIDATOR_PARALLEL=4       Run 4 validations in parallel

OUTPUT:
  VALIDATOR_OUTPUT_FILE      Write JSON to file

FUNCTIONS:
  validator_api_run              Run validation on files
  validator_api_validate_staged  Validate staged git files
  validator_api_validate_dir     Validate directory
  validator_api_status           Get pass/fail status
  validator_api_get_results      Get results as JSON
  validator_api_version          Show version
  validator_api_help             Show this help

EXIT CODES:
  0 - All validations passed
  1 - One or more validations failed
  2 - Error in API execution

EXAMPLES:
  # Console output
  validator_api_run src/app.py

  # JSON output
  VALIDATOR_OUTPUT=json validator_api_run script.sh

  # Parallel validation
  VALIDATOR_PARALLEL=4 validator_api_run *.py

  # Validate staged files
  validator_api_validate_staged

  # Validate directory
  validator_api_validate_dir src "*.py"

  # Write to file
  VALIDATOR_OUTPUT=json VALIDATOR_OUTPUT_FILE=results.json \
    validator_api_run file1.py file2.js
EOT
}

#!/usr/bin/env bash
# =============================================================================
# 🔧 VALIDATOR API INTERNAL HELPERS
# =============================================================================
# Internal utility functions for the validator API.
# Split from api.sh to keep the main API focused on public interfaces.
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_VALIDATOR_API_INTERNAL_LOADED:-}" ]] && return 0
readonly _VALIDATOR_API_INTERNAL_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# INPUT VALIDATION
# =============================================================================

_validator_api_validate_env() {
    # Validate VALIDATOR_OUTPUT
    case "$VALIDATOR_OUTPUT" in
        console | json) ;;
        *)
            echo "Error: VALIDATOR_OUTPUT must be 'console' or 'json', got '$VALIDATOR_OUTPUT'" >&2
            return 2
            ;;
    esac

    # Validate VALIDATOR_PARALLEL is a non-negative integer
    if [[ ! "$VALIDATOR_PARALLEL" =~ ^[0-9]+$ ]]; then
        echo "Error: VALIDATOR_PARALLEL must be a non-negative integer, got '$VALIDATOR_PARALLEL'" >&2
        return 2
    fi

    # Validate VALIDATOR_OUTPUT_FILE is writable if set
    if [[ -n "$VALIDATOR_OUTPUT_FILE" ]]; then
        local output_dir
        output_dir=$(dirname "$VALIDATOR_OUTPUT_FILE")
        if [[ ! -d "$output_dir" ]] || [[ ! -w "$output_dir" ]]; then
            echo "Error: Output directory not writable: $output_dir" >&2
            return 2
        fi
    fi

    return 0
}

# =============================================================================
# INTERNAL STATE (uses temp files for cross-process result storage)
# =============================================================================

# Track files processed (indexed array)
_VALIDATOR_FILES=()

# Start time for performance tracking
_VALIDATOR_START_TIME=""

# Temp directory for parallel execution
_VALIDATOR_API_TMP_DIR="${TMPDIR:-/tmp}/validator-api-$$"
_VALIDATOR_API_JSON_OUTPUT=""

# =============================================================================
# TEMP FILE HELPERS (for cross-process result storage)
# =============================================================================

# Encode filename for safe filesystem storage
_validator_encode_filename() {
    printf '%s' "$1" | base64 | tr -d '\n=' | tr '/+' '_-'
}

# Store result for a file
_validator_set_result() {
    local file="$1"
    local result="$2"
    local encoded
    encoded=$(_validator_encode_filename "$file")
    echo "$result" >"$_VALIDATOR_API_TMP_DIR/results/$encoded"
}

# Get result for a file
_validator_get_result() {
    local file="$1"
    local encoded
    encoded=$(_validator_encode_filename "$file")
    [[ -f "$_VALIDATOR_API_TMP_DIR/results/$encoded" ]] && command cat "$_VALIDATOR_API_TMP_DIR/results/$encoded"
}

# Store error for a file
_validator_set_error() {
    local file="$1"
    local error="$2"
    local encoded
    encoded=$(_validator_encode_filename "$file")
    echo "$error" >>"$_VALIDATOR_API_TMP_DIR/errors/$encoded"
}

# Get errors for a file
_validator_get_errors() {
    local file="$1"
    local encoded
    encoded=$(_validator_encode_filename "$file")
    [[ -f "$_VALIDATOR_API_TMP_DIR/errors/$encoded" ]] && command cat "$_VALIDATOR_API_TMP_DIR/errors/$encoded"
}

# Check if file has errors
_validator_has_errors() {
    local file="$1"
    local encoded
    encoded=$(_validator_encode_filename "$file")
    [[ -s "$_VALIDATOR_API_TMP_DIR/errors/$encoded" ]]
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Initialize validator state
_validator_api_init() {
    _VALIDATOR_FILES=()
    _VALIDATOR_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

    # Create temp directory structure for results storage
    command rm -rf "$_VALIDATOR_API_TMP_DIR" 2>/dev/null
    mkdir -p "$_VALIDATOR_API_TMP_DIR/results"
    mkdir -p "$_VALIDATOR_API_TMP_DIR/errors"
    mkdir -p "$_VALIDATOR_API_TMP_DIR/parallel"
}

# Cleanup on exit
_validator_api_cleanup() {
    [[ -d "$_VALIDATOR_API_TMP_DIR" ]] && command rm -rf "$_VALIDATOR_API_TMP_DIR" 2>/dev/null
}

# Preserve any existing EXIT trap so we can chain cleanup safely.
_VALIDATOR_EXISTING_TRAP=""

_validator_trap_handler() {
    if [[ -n "$_VALIDATOR_EXISTING_TRAP" ]]; then
        eval "$_VALIDATOR_EXISTING_TRAP"
    fi
    _validator_api_cleanup
}

# Register cleanup (append to existing traps rather than replace)
_validator_register_cleanup() {
    # Get existing trap command
    _VALIDATOR_EXISTING_TRAP=$(trap -p EXIT | sed "s/trap -- '\\(.*\\)' EXIT/\\1/" || true)
    trap '_validator_trap_handler' EXIT
}
_validator_register_cleanup

# Calculate elapsed time
_validator_api_elapsed() {
    local end_time
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    if command_exists "bc"; then
        echo "$end_time - $_VALIDATOR_START_TIME" | bc
    else
        # Fallback for systems without bc: truncate to integers
        local start_s=${_VALIDATOR_START_TIME/.*/}
        local end_s=${end_time/.*/}
        echo "$((end_s - start_s))"
    fi
}

# =============================================================================
# VALIDATION WRAPPERS (Capture Results)
# =============================================================================

# Validate a single file and capture results
# Usage: _validator_validate_file "file"
_validator_validate_file() {
    local file="$1"

    # Track this file
    _VALIDATOR_FILES+=("$file")

    # Skip if file doesn't exist
    [[ ! -f "$file" ]] && {
        _validator_set_result "$file" "skipped"
        _validator_set_error "$file" "File not found"
        return 0
    }

    # Run validation through core API (disable set -u temporarily for compatibility)
    local validation_result=0
    set +u
    validate_file "$file" 2>/dev/null || validation_result=$?
    set -u

    if [[ $validation_result -eq 0 ]]; then
        _validator_set_result "$file" "pass"
    else
        _validator_set_result "$file" "fail"
        # Capture error details
        local errors
        errors=$(_validator_api_capture_errors "$file" 2>&1 || true)
        [[ -n "$errors" ]] && _validator_set_error "$file" "$errors"
    fi
}

# Capture validation errors for a file
_validator_api_capture_errors() {
    local file="$1"
    local errors=()

    # Check each validator for errors
    if file_validator_has_violations; then
        errors+=("File length exceeds limits")
    fi

    if security_validator_has_violations; then
        errors+=("Sensitive filename detected")
    fi

    if syntax_validator_has_errors; then
        errors+=("Syntax errors detected")
    fi

    if workflow_validator_has_errors; then
        errors+=("Workflow validation failed")
    fi

    if infra_validator_has_errors; then
        errors+=("Infrastructure validation failed")
    fi

    if phantom_validator_has_violations; then
        errors+=("Supply chain security issues detected")
    fi

    printf '%s\n' "${errors[@]}"
}

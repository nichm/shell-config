#!/usr/bin/env bash
# =============================================================================
# security/opengrep-validator.sh - OpenGrep security scanning validator
# =============================================================================
# Uses OpenGrep (fast fork of Semgrep) for static security analysis
# https://github.com/opengrep/opengrep
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/validation/validators/security/opengrep-validator.sh"
#   validate_opengrep_scanning
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_OPENGREP_VALIDATOR_LOADED:-}" ]] && return 0
readonly _OPENGREP_VALIDATOR_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Configuration
OPENGREP_TIMEOUT=10 # Total timeout for the scan (seconds)

# Validate files with OpenGrep security scanning
validate_opengrep_scanning() {
    local files=("$@")
    local supported_files=()

    # Check if OpenGrep is installed
    if ! command_exists "opengrep"; then
        opengrep_validator_show_warning "OpenGrep not installed - skipping security scan"
        echo "   💡 Install: brew tap opengrep/opengrep && brew install opengrep" >&2
        echo "   💡 Or: pip install opengrep" >&2
        return 0
    fi

    # Filter to supported file types
    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && continue

        # Check file extension
        ext="${file##*.}"
        case "$ext" in
            js | ts | jsx | tsx | py | sh | bash | yml | yaml | json | rb | go | java | php | cs | cpp | c | h)
                supported_files+=("$file")
                ;;
        esac
    done

    if [[ ${#supported_files[@]} -eq 0 ]]; then
        return 0 # No supported files to scan
    fi

    opengrep_validator_log_info "Running OpenGrep on ${#supported_files[@]} file(s)..."

    # Build OpenGrep command
    local opengrep_cmd=(opengrep)

    # Add config if exists
    local opengrep_config="${SHELL_CONFIG_DIR}/.opengrep.yml"
    if [[ -f "$opengrep_config" ]]; then
        opengrep_cmd+=(--config "$opengrep_config")
    else
        # Use auto-config if no custom config
        opengrep_cmd+=(--config auto)
    fi

    # Add files and options
    opengrep_cmd+=("${supported_files[@]}")
    opengrep_cmd+=(--error) # Exit with error code if findings
    opengrep_cmd+=(--skip-unknown-extensions)

    # Run OpenGrep with timeout
    local output
    local exit_code
    if output=$(timeout "$OPENGREP_TIMEOUT" "${opengrep_cmd[@]}" 2>&1); then
        opengrep_validator_log_success "OpenGrep scan passed!"
        return 0
    else
        exit_code=$?
        case $exit_code in
            124)
                opengrep_validator_show_error "OpenGrep scan timed out after ${OPENGREP_TIMEOUT}s"
                echo "   💡 Bypass: GIT_SKIP_HOOKS=1 git commit -m 'message'" >&2
                return 1
                ;;
            1)
                opengrep_validator_show_error "OpenGrep found security issues"
                if [[ -n "$output" ]]; then
                    echo "$output" >&2
                fi
                echo "   💡 Run: opengrep --config .opengrep.yml . for details" >&2
                echo "   💡 Bypass: GIT_SKIP_HOOKS=1 git commit -m 'message'" >&2
                return 1
                ;;
            *)
                opengrep_validator_show_error "OpenGrep failed with exit code $exit_code"
                if [[ -n "$output" ]]; then
                    echo "$output" >&2
                fi
                return 1
                ;;
        esac
    fi
}

# Validator interface functions
opengrep_validator_reset() {
    # Reset any internal state if needed
    return 0
}

opengrep_validator_show_errors() {
    # This validator handles its own error display
    return 0
}

opengrep_validator_show_warning() {
    log_warning "OpenGrep: $1"
}

opengrep_validator_show_error() {
    log_error "OpenGrep: $1"
}

opengrep_validator_log_info() {
    log_info "OpenGrep: $1"
}

opengrep_validator_log_success() {
    log_success "OpenGrep: $1"
}

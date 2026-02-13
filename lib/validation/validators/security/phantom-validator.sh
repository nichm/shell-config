#!/usr/bin/env bash
# =============================================================================
# 🛡️ PHANTOM VALIDATOR - Supply Chain Security
# =============================================================================
# Validates packages against typosquatting and slopsquatting attacks
# Uses Phantom Guard for dependency security scanning
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_PHANTOM_VALIDATOR_LOADED:-}" ]] && return 0
readonly _PHANTOM_VALIDATOR_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# DEPENDENCIES - determine validation lib directory
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _PHANTOM_VALIDATOR_DIR="$VALIDATION_LIB_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _PHANTOM_VALIDATOR_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # Go up two levels: validators/security/ -> validators/ -> validation/
    _PHANTOM_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    _PHANTOM_VALIDATOR_DIR="${HOME}/.shell-config/lib/validation"
fi

# Source shared utilities
# shellcheck source=../../shared/reporters.sh
source "$_PHANTOM_VALIDATOR_DIR/shared/reporters.sh"

# Configuration file location
PHANTOM_CONFIG_FILE="${PHANTOM_CONFIG_FILE:-${HOME}/.phantom-guard/config.yml}"
if [[ -f "$_PHANTOM_VALIDATOR_DIR/validators/security/config/phantom.yml" ]]; then
    PHANTOM_CONFIG_FILE="$_PHANTOM_VALIDATOR_DIR/validators/security/config/phantom.yml"
fi

_PHANTOM_VERBOSE="${VALIDATION_VERBOSE:-0}"

# VIOLATION TRACKING
_PHANTOM_VIOLATIONS=()

phantom_validator_reset() {
    _PHANTOM_VIOLATIONS=()
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Check if phantom-guard is available
phantom_guard_available() {
    command_exists "phantom-guard"
}

# Validate a single package
# Usage: validate_package_security "package-name"
# Returns: 0 if safe, 1 if suspicious
validate_package_security() {
    local package="$1"

    if ! phantom_guard_available; then
        [[ "$_PHANTOM_VERBOSE" == "1" ]] && validation_verbose "phantom-guard not installed, skipping package validation"
        return 0
    fi

    [[ "$_PHANTOM_VERBOSE" == "1" ]] && validation_verbose "Checking package: $package"

    # Run phantom-guard validation
    local output
    local exit_code

    # Use phantom-guard to validate the package
    # Use -- to prevent argument injection from malicious package names
    local exit_code=0
    output=$(phantom-guard validate -- "$package" 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # Package passed validation
        return 0
    else
        # Package flagged as suspicious
        _PHANTOM_VIOLATIONS+=("$package: $output (exit code: $exit_code)")
        return 1
    fi
}

# Validate package.json dependencies
# Usage: validate_package_json "/path/to/package.json"
validate_package_json() {
    local package_json="$1"

    [[ ! -f "$package_json" ]] && return 0

    if ! phantom_guard_available; then
        [[ "$_PHANTOM_VERBOSE" == "1" ]] && validation_verbose "phantom-guard not installed, skipping package.json validation"
        return 0
    fi

    [[ "$_PHANTOM_VERBOSE" == "1" ]] && validation_verbose "Validating package.json: $package_json"

    # Use phantom-guard to check all dependencies
    # Use -- to prevent argument injection from malicious file paths
    if ! phantom-guard check -- "$package_json" >/dev/null 2>&1; then
        _PHANTOM_VIOLATIONS+=("$package_json: Contains suspicious dependencies")
        return 1
    fi

    return 0
}

# Validate requirements.txt dependencies
# Usage: validate_requirements_txt "/path/to/requirements.txt"
validate_requirements_txt() {
    local requirements_txt="$1"

    [[ ! -f "$requirements_txt" ]] && return 0

    if ! phantom_guard_available; then
        [[ "$_PHANTOM_VERBOSE" == "1" ]] && validation_verbose "phantom-guard not installed, skipping requirements.txt validation"
        return 0
    fi

    [[ "$_PHANTOM_VERBOSE" == "1" ]] && validation_verbose "Validating requirements.txt: $requirements_txt"

    # Extract package names from requirements.txt and validate each
    local failed=0
    local package

    while IFS= read -r line; do
        # Skip comments and empty lines (combined check for efficiency)
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        # Skip lines starting with - (pip options like --index-url, -e, etc.)
        # These are not package names and could be argument injection attempts
        [[ "$line" =~ ^[[:space:]]*- ]] && continue

        # Extract package name (before any version specifiers)
        package=$(sed 's/[=<>!~].*//' <<<"$line" | xargs)

        # Skip if package name starts with hyphen (potential argument injection)
        if [[ -n "$package" ]] && [[ ! "$package" =~ ^- ]]; then
            if ! validate_package_security "$package"; then
                failed=1
            fi
        fi
    done <"$requirements_txt"

    return $failed
}

# Validate all package files in a directory
# Usage: validate_package_files_in_dir "/path/to/project"
validate_package_files_in_dir() {
    local dir="$1"

    [[ ! -d "$dir" ]] && return 0

    local failed=0

    # Check package.json files
    for pkg_file in "$dir"/package.json "$dir"/*/package.json; do
        [[ -f "$pkg_file" ]] && validate_package_json "$pkg_file" || failed=1
    done

    # Check requirements.txt files
    for req_file in "$dir"/requirements.txt "$dir"/*/requirements.txt; do
        [[ -f "$req_file" ]] && validate_requirements_txt "$req_file" || failed=1
    done

    return $failed
}

# =============================================================================
# REPORTING
# =============================================================================

phantom_validator_has_violations() {
    [[ ${#_PHANTOM_VIOLATIONS[@]} -gt 0 ]]
}

phantom_validator_violation_count() {
    echo ${#_PHANTOM_VIOLATIONS[@]}
}

phantom_validator_show_violations() {
    if ! phantom_validator_has_violations; then
        [[ "$_PHANTOM_VERBOSE" == "1" ]] && validation_log_success "All packages passed supply chain security validation"
        return 0
    fi

    validation_log_error "Supply chain security issues found: ${#_PHANTOM_VIOLATIONS[@]} issue(s)"
    echo "" >&2

    for violation in "${_PHANTOM_VIOLATIONS[@]}"; do
        echo "  - $violation" >&2
    done

    echo "" >&2
    echo "These packages may be subject to typosquatting or slopsquatting attacks." >&2
    echo "Consider:" >&2
    echo "  • Verifying package names are correct" >&2
    echo "  • Checking package maintainers and download counts" >&2
    echo "  • Using package pinning for critical dependencies" >&2
    echo "" >&2
    validation_bypass_hint "GIT_SKIP_PHANTOM_CHECK" "Fix dependencies or bypass"
    return 1
}

# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

# Validate and report in one call
validate_and_report_supply_chain() {
    local target="${1:-.}"

    # Reset violations
    phantom_validator_reset

    if [[ -f "$target" ]]; then
        # Single file
        case "$target" in
            *package.json) validate_package_json "$target" ;;
            *requirements.txt) validate_requirements_txt "$target" ;;
        esac
    else
        # Directory
        validate_package_files_in_dir "$target"
    fi

    phantom_validator_show_violations
}

# Export functions
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f phantom_validator_reset 2>/dev/null || true
    export -f validate_package_security 2>/dev/null || true
    export -f validate_package_json 2>/dev/null || true
    export -f validate_requirements_txt 2>/dev/null || true
    export -f validate_package_files_in_dir 2>/dev/null || true
    export -f phantom_validator_has_violations 2>/dev/null || true
    export -f phantom_validator_show_violations 2>/dev/null || true
    export -f validate_and_report_supply_chain 2>/dev/null || true
fi

#!/usr/bin/env bash
# Infra config validation: nginx, terraform, docker-compose, k8s, ansible, packer

# Prevent double-sourcing
set -euo pipefail
[[ -n "${_INFRA_VALIDATOR_LOADED:-}" ]] && return 0
readonly _INFRA_VALIDATOR_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# DEPENDENCIES - determine validation lib directory
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _INFRA_VALIDATOR_DIR="$VALIDATION_LIB_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _INFRA_VALIDATOR_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # Go up two levels: validators/infra/ -> validators/ -> validation/
    _INFRA_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    _INFRA_VALIDATOR_DIR="${HOME}/.shell-config/lib/validation"
fi

# Source shared utilities
source "$_INFRA_VALIDATOR_DIR/shared/reporters.sh"
source "$_INFRA_VALIDATOR_DIR/shared/file-operations.sh"
# shellcheck source=infra-validator-checks.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/infra-validator-checks.sh"

_INFRA_VERBOSE="${VALIDATION_VERBOSE:-0}"
_INFRA_REPO_ROOT=""

_INFRA_ERRORS=()
_INFRA_ERROR_DETAILS=()
_INFRA_ERROR_SEVERITY=() # "BLOCKING" or "WARNING"

# Debug output directory for error details
_INFRA_DEBUG_DIR=""

infra_validator_reset() {
    _INFRA_ERRORS=()
    _INFRA_ERROR_DETAILS=()
    _INFRA_ERROR_SEVERITY=()

    # Create temp directory for debug output
    if [[ -z "$_INFRA_DEBUG_DIR" ]]; then
        _INFRA_DEBUG_DIR=$(mktemp -d)
        trap 'rm -rf "$_INFRA_DEBUG_DIR" 2>/dev/null || true' EXIT INT TERM
    fi

    _INFRA_REPO_ROOT=""
}

# Get repo root (cached)
_get_infra_repo_root() {
    if [[ -z "$_INFRA_REPO_ROOT" ]]; then
        _INFRA_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    fi
    echo "$_INFRA_REPO_ROOT"
}

# Check tool version against minimum required
# Usage: _check_tool_version <tool_name> <min_version> <version_arg>
# Returns: 0 if version OK, 1 if too old, 2 if version check not available
_check_tool_version() {
    local tool_name="$1"
    local min_version="$2"
    local version_arg="$3"

    # Skip check if min_version not set
    [[ -z "$min_version" ]] && return 0

    # Skip if tool not installed
    if ! command_exists "$tool_name"; then
        return 2
    fi

    # Get current version
    local current_version
    current_version=$("$tool_name" "$version_arg" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    # If we couldn't parse version, skip check (don't fail)
    [[ -z "$current_version" ]] && return 0

    # Compare versions (simple string comparison works for X.Y.Z)
    if [[ "$current_version" < "$min_version" ]]; then
        echo "WARNING: $tool_name version $current_version is below minimum $min_version" >&2
        return 1
    fi

    return 0
}

# =============================================================================
# REPORTING
# =============================================================================

infra_validator_has_errors() {
    [[ ${#_INFRA_ERRORS[@]} -gt 0 ]]
}

infra_validator_error_count() {
    echo ${#_INFRA_ERRORS[@]}
}

# Show errors with formatted output
infra_validator_show_errors() {
    if ! infra_validator_has_errors; then
        [[ "$_INFRA_VERBOSE" == "1" ]] && validation_log_success "All infrastructure configs valid"
        return 0
    fi

    local blocking_count=0
    local warning_count=0

    # Count errors by severity
    for severity in "${_INFRA_ERROR_SEVERITY[@]}"; do
        if [[ "$severity" == "BLOCKING" ]]; then
            ((blocking_count++))
        else
            ((warning_count++))
        fi
    done

    echo "" >&2

    # Show blocking errors first
    if [[ $blocking_count -gt 0 ]]; then
        validation_log_error "Infrastructure validation failed ($blocking_count blocking issue(s)):"
        echo "" >&2

        for i in "${!_INFRA_ERROR_SEVERITY[@]}"; do
            if [[ "${_INFRA_ERROR_SEVERITY[$i]}" == "BLOCKING" ]]; then
                echo "  ❌ ${_INFRA_ERROR_DETAILS[$i]}" >&2
            fi
        done

        echo "" >&2
        validation_bypass_hint "GIT_SKIP_HOOKS" "Fix configs or bypass"
        echo "" >&2
    fi

    # Show warnings separately
    if [[ $warning_count -gt 0 ]]; then
        validation_log_warning "Infrastructure validation warnings ($warning_count issue(s)):"
        echo "" >&2

        for i in "${!_INFRA_ERROR_SEVERITY[@]}"; do
            if [[ "${_INFRA_ERROR_SEVERITY[$i]}" == "WARNING" ]]; then
                echo "  ⚠️  ${_INFRA_ERROR_DETAILS[$i]}" >&2
            fi
        done

        echo "" >&2
    fi

    # Only exit with error if there are blocking issues
    [[ $blocking_count -gt 0 ]] && return 1
    return 0
}

# =============================================================================
# EXPORTS
# =============================================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f infra_validator_reset 2>/dev/null || true
    export -f validate_nginx_config 2>/dev/null || true
    export -f validate_terraform_config 2>/dev/null || true
    export -f validate_docker_compose_config 2>/dev/null || true
    export -f validate_kubernetes_manifests 2>/dev/null || true
    export -f validate_ansible_playbooks 2>/dev/null || true
    export -f validate_packer_templates 2>/dev/null || true
    export -f validate_dockerfiles 2>/dev/null || true
    export -f validate_infra_configs 2>/dev/null || true
    export -f infra_validator_has_errors 2>/dev/null || true
    export -f infra_validator_error_count 2>/dev/null || true
    export -f infra_validator_show_errors 2>/dev/null || true
fi

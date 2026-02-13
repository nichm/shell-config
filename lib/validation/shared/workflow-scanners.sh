#!/usr/bin/env bash
# =============================================================================
# 🔒 WORKFLOW SCANNERS - Shared Scanner Implementation
# =============================================================================
# Unified scanning logic for GitHub Actions workflows.
# Used by both lib/validation/validators/workflow-validator.sh and lib/bin/gha-scan
# This module provides:
# - Actionlint syntax validation
# - Zizmor security scanning
# - Tool detection and version checking
# - Configuration file discovery
# =============================================================================
# NOTE: This is a SHARED utility - keep it focused on scanning logic only.
# Do not add reporting or orchestration logic here.
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_WORKFLOW_SCANNERS_LOADED:-}" ]] && return 0
readonly _WORKFLOW_SCANNERS_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# TOOL DETECTION

_wf_check_tool() {
    local tool="$1"
    if command_exists "$tool"; then
        return 0
    elif [[ -x "$HOME/.local/bin/$tool" ]]; then
        return 0
    fi
    return 1
}

# Get the path to a workflow scanning tool
# Usage: _wf_get_tool_path "actionlint"
# Outputs: Path to tool or empty string
_wf_get_tool_path() {
    local tool="$1"
    if command_exists "$tool"; then
        command -v "$tool"
    elif [[ -x "$HOME/.local/bin/$tool" ]]; then
        echo "$HOME/.local/bin/$tool"
    fi
}

# Get version of a workflow scanning tool
# Usage: _wf_get_version "actionlint"
# Outputs: Version string or "unknown"
_wf_get_version() {
    local tool="$1"
    local cmd
    cmd=$(_wf_get_tool_path "$tool")
    [[ -z "$cmd" ]] && echo "not installed" && return

    local ver
    case "$tool" in
        actionlint)
            ver=$("$cmd" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        zizmor)
            ver=$("$cmd" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        poutine)
            ver=$("$cmd" version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        *)
            ver="unknown"
            ;;
    esac
    echo "${ver:-unknown}"
}

# CONFIGURATION DISCOVERY

# Find a configuration file for workflow scanners
# Usage: _wf_find_config "actionlint.yaml" "/path/to/repo"
# Outputs: Config file path or empty string
_wf_find_config() {
    local config_name="$1"
    local repo_root="${2:-$(pwd)}"

    # Check repo-level config
    if [[ -f "$repo_root/.github/$config_name" ]]; then
        echo "$repo_root/.github/$config_name"
        return
    fi

    # Check root-level config
    if [[ -f "$repo_root/$config_name" ]]; then
        echo "$repo_root/$config_name"
        return
    fi

    # Check shell-config defaults for zizmor
    if [[ "$config_name" == ".zizmor.yml" ]]; then
        local sc_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}"
        local default_config="$sc_dir/lib/validation/validators/gha/config/.zizmor.yml"
        if [[ -f "$default_config" ]]; then
            echo "$default_config"
            return
        fi
    fi

    echo ""
}

# ACTIONLINT SCANNER

_wf_run_actionlint() {
    local target="$1"
    local repo_root="${2:-$(pwd)}"
    local error_count_var="${3:-}"

    if ! _wf_check_tool "actionlint"; then
        echo "Warning: actionlint not installed (brew install actionlint)" >&2
        return 2
    fi

    local cmd
    cmd=$(_wf_get_tool_path actionlint)

    # Build arguments
    local args=()
    local config
    config=$(_wf_find_config "actionlint.yaml" "$repo_root")
    [[ -n "$config" ]] && args+=("-config-file" "$config")

    # Run actionlint
    local result exit_code
    result=$("$cmd" "${args[@]}" -- "$target" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi

    # Filter out shellcheck info/style issues (not real bugs)
    # Use bash native filtering to avoid fork overhead
    local filtered=""
    local error_count=0
    local line

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip info/style messages
        if [[ "$line" =~ SC[0-9]*:(info|style): ]]; then
            continue
        fi
        # Count and collect actual errors (lines with line:col format)
        if [[ "$line" =~ :[0-9]+:[0-9]+: ]]; then
            ((++error_count))
            filtered+="${line}"$'\n'
        fi
    done <<<"$result"

    if [[ "$error_count" -gt 0 ]]; then
        # Store error count if variable name provided (safe indirect assignment)
        if [[ -n "$error_count_var" ]]; then
            printf -v "$error_count_var" "%d" "$error_count"
        fi

        # Output filtered errors
        printf '%s' "$filtered"
        return 1
    fi

    return 0
}

# ZIZMOR SCANNER

_wf_run_zizmor() {
    local target="$1"
    local repo_root="${2:-$(pwd)}"
    local findings_var="${3:-}"

    if ! _wf_check_tool "zizmor"; then
        echo "Warning: zizmor not installed (brew install zizmor)" >&2
        return 2
    fi

    local cmd
    cmd=$(_wf_get_tool_path zizmor)

    # Build arguments
    local args=()
    local config
    config=$(_wf_find_config ".zizmor.yml" "$repo_root")
    [[ -n "$config" ]] && args+=("--config" "$config")

    # Run zizmor
    local result
    result=$("$cmd" "${args[@]}" -- "$target" 2>&1)

    # Parse summary line (e.g., "zizmor: 3 findings (1 high)")
    local summary
    summary=$(echo "$result" | tail -1)

    if [[ "$summary" =~ ([0-9]+)\ findings ]]; then
        local findings="${BASH_REMATCH[1]}"
        # Store findings count if variable name provided (safe indirect assignment)
        if [[ -n "$findings_var" ]]; then
            printf -v "$findings_var" "%d" "$findings"
        fi

        if [[ $findings -eq 0 ]]; then
            return 0
        else
            # Show high-severity issues
            grep -A5 "^error\[" <<<"$result" | head -40
            return 1
        fi
    fi

    return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f _wf_check_tool 2>/dev/null || true
    export -f _wf_get_tool_path 2>/dev/null || true
    export -f _wf_get_version 2>/dev/null || true
    export -f _wf_find_config 2>/dev/null || true
    export -f _wf_run_actionlint 2>/dev/null || true
    export -f _wf_run_zizmor 2>/dev/null || true
fi

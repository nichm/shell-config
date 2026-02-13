#!/usr/bin/env bash
# =============================================================================
# aliases/gha.sh - GitHub Actions security scanning
# =============================================================================
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/aliases/gha.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_GHA_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_GHA_LOADED=1

# GitHub Actions Security Scanning
# Usage: gha-scan [-q|-a|-m|-v] [path]
#   -q: Quick mode (actionlint only)
#   -a: All scanners (actionlint + zizmor + poutine + octoscan)
#   -m: Modified files only (staged for commit)
#   -v: Verbose output
gha-scan() {
    # Delegate to the gha-scan binary to avoid duplicating logic
    local binary_path
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    binary_path="$script_dir/bin/gha-scan"

    if [[ -x "$binary_path" ]]; then
        "$binary_path" "$@"
        return $?
    fi

    echo "❌ ERROR: gha-scan binary not found" >&2
    echo "ℹ️  WHY: GitHub Actions security scanning is unavailable" >&2
    echo "💡 FIX: Ensure shell-config is installed and lib/bin/gha-scan exists" >&2
    return 2
}

alias ghas='gha-scan'
alias ghasq='gha-scan -q'
alias ghasm='gha-scan -m'
alias ghasv='gha-scan -v'

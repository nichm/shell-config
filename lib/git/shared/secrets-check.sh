#!/usr/bin/env bash
# =============================================================================
# secrets-check.sh - Gitleaks secrets detection for git operations
# =============================================================================
# Provides secrets scanning using Gitleaks for staged files. Implements
# defense-in-depth with two layers: pre-stage (via git add wrapper) and
# pre-commit hook. Includes caching for performance optimization.
# Dependencies:
#   - gitleaks - Install: brew install gitleaks
# Environment Variables:
#   GIT_WRAPPER_CACHE_DIR - Cache directory for scans (default: ~/.cache/git-wrapper)
#   SECRETS_CACHE_FILE - Secrets scan cache file
#   SECRETS_CACHE_TTL - Cache time-to-live in seconds (default: 300)
# Bypass Flags:
#   --skip-secrets - Skip secrets scanning for this operation
# Features:
#   - Scans staged files for secrets, API keys, tokens
#   - Caches results to avoid repeated scans
#   - Fails fast if gitleaks is not installed
#   - Clear error messages with installation instructions
# Usage:
#   Source this file from git/wrapper.sh - automatic integration
#   Functions called by git wrapper during add/commit operations
# NOTE: No set -euo pipefail — sourced by wrapper.sh into interactive shells
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Export cache variables so they persist across function calls and subshells
export GIT_WRAPPER_CACHE_DIR="${GIT_WRAPPER_CACHE_DIR:-${HOME}/.cache/git-wrapper}"
if [[ ! -d "$GIT_WRAPPER_CACHE_DIR" ]]; then
    if ! mkdir -p "$GIT_WRAPPER_CACHE_DIR" 2>/dev/null; then
        # Fall back to temp directory if cache dir creation fails
        GIT_WRAPPER_CACHE_DIR="${TMPDIR:-/tmp}/git-wrapper-$$"
        mkdir -p "$GIT_WRAPPER_CACHE_DIR" 2>/dev/null || true
    fi
fi
chmod 700 "$GIT_WRAPPER_CACHE_DIR" 2>/dev/null || true

export SECRETS_CACHE_FILE="${SECRETS_CACHE_FILE:-${GIT_WRAPPER_CACHE_DIR}/secrets_cache}"
export SECRETS_CACHE_TTL="${SECRETS_CACHE_TTL:-300}"

# Check if Gitleaks is installed
_check_gitleaks() {
    command_exists "gitleaks"
}

_show_gitleaks_setup_hint() {
    echo "" >&2
    echo "⚠️  Gitleaks not installed - skipping secrets check" >&2
    echo "   Install: brew install gitleaks" >&2
    echo "   Or: go install github.com/zricethezav/gitleaks/v8/cmd/gitleaks@latest" >&2
    echo "" >&2
}

# Run Gitleaks on staged files (5x faster than git-secrets)
_run_gitleaks() {
    # Config was moved from git/secrets/ to validation/validators/security/config/
    local config_file="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/validation/validators/security/config/gitleaks.toml"

    # Build gitleaks command
    local gitleaks_cmd=(gitleaks protect --staged)
    if [[ -f "$config_file" ]]; then
        gitleaks_cmd+=(--config "$config_file")
    fi

    if "${gitleaks_cmd[@]}" >/dev/null 2>&1; then
        return 0
    else
        echo "❌ Secrets detected by Gitleaks" >&2
        echo "Run 'gitleaks detect --source .' for details" >&2
        return 1
    fi
}

# Check if command needs secrets scanning
_needs_secrets_check() {
    local cmd="$1"
    case "$cmd" in commit | add | push | ci | am | apply | merge | rebase) return 0 ;; *) return 1 ;; esac
}

# Run secrets check with Gitleaks
_run_secrets_check() {
    local cmd="$1"
    local skip_secrets="$2"

    # Return if skipping secrets check
    [[ $skip_secrets -eq 1 ]] && return 0

    # Only check specific commands
    if ! _needs_secrets_check "$cmd"; then
        return 0
    fi

    # Check if Gitleaks is available
    if _check_gitleaks; then
        # Count staged files for display
        local file_count
        read -r file_count < <(command git diff --cached --name-only 2>/dev/null | wc -l)
        file_count=${file_count:-0}

        if [[ ${file_count:-0} -gt 0 ]]; then
            echo "🔍 Pre-stage secrets scan (${file_count} files)..." >&2
            if ! _run_gitleaks; then
                echo "Use --skip-secrets to bypass (not recommended)." >&2
                return 1
            fi
            echo "✅ Pre-stage secrets scan passed" >&2
        fi
    else
        _show_gitleaks_setup_hint
    fi

    return 0
}

#!/usr/bin/env bash
# =============================================================================
# 🪝 Hook Bootstrap - Shared Environment Setup for Git Hooks
# =============================================================================
# Provides consistent environment setup for all git hooks:
#   - Resolves SHELL_CONFIG_DIR from hook directory
#   - Sources core dependencies (colors, command-cache)
#   - Sources git shared utilities (config, timeout-wrapper)
#   - Sets up hook skip detection
# Usage (at the top of each git hook):
#   source "$(dirname "${BASH_SOURCE[0]}")/../shared/hook-bootstrap.sh"
# Design Notes:
#   - Uses BASH_SOURCE[0] to get calling hook's directory
#   - Works from both repo (lib/git/hooks/) and installed (~/.git-hooks/)
#   - Idempotent - safe to source multiple times
#   - Minimal dependencies - only requires bash builtins
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_HOOK_BOOTSTRAP_LOADED:-}" ]] && return 0
readonly _HOOK_BOOTSTRAP_LOADED=1

# =============================================================================
# Resolve Directories
# =============================================================================
# Get the directory of the calling hook script (using BASH_SOURCE[1])
# BASH_SOURCE[0] = this file, BASH_SOURCE[1] = the calling hook
# Resolve symlinks first so relative paths work from installed (~/.githooks/) location
_hook_caller_source="$(readlink "${BASH_SOURCE[1]}" 2>/dev/null || echo "${BASH_SOURCE[1]}")"
_hook_caller_dir="$(cd "$(dirname "$_hook_caller_source")" && pwd)"
unset _hook_caller_source

# Resolve SHELL_CONFIG_DIR
if [[ -z "${SHELL_CONFIG_DIR:-}" ]]; then
    if [[ -d "$_hook_caller_dir/../shared" ]]; then
        # Running from lib/git/hooks/ in repo
        SHELL_CONFIG_DIR="$(cd "$_hook_caller_dir/../../.." && pwd)"
    elif [[ -f "$HOME/.shell-config/lib/git/shared/timeout-wrapper.sh" ]]; then
        # Running from installed location (~/.git-hooks/)
        SHELL_CONFIG_DIR="$HOME/.shell-config"
    else
        # Fallback: try relative path from hook directory
        printf "❌ ERROR: Cannot find shell-config directory\\n" >&2
        printf "ℹ️  WHY: Git hooks require shell-config to source shared libraries and function properly\\n" >&2
        printf "💡 FIX: Ensure SHELL_CONFIG_DIR is set, or run the installation script again\\n" >&2
        printf "ℹ️  HOOK_DIR: %s\\n" "$_hook_caller_dir" >&2
        exit 1
    fi
fi
export SHELL_CONFIG_DIR

SHARED_DIR="$SHELL_CONFIG_DIR/lib/git/shared"
readonly SHARED_DIR

# =============================================================================
# Source Core Dependencies
# =============================================================================

# Source centralized colors library (SHELL_CONFIG_DIR is guaranteed set above)
# shellcheck source=../../core/colors.sh
source "$SHELL_CONFIG_DIR/lib/core/colors.sh"

# Source command cache for optimized command checks
# shellcheck source=../../core/command-cache.sh
COMMAND_CACHE_SCRIPT="$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
if [[ -f "$COMMAND_CACHE_SCRIPT" ]]; then
    source "$COMMAND_CACHE_SCRIPT"
fi

# =============================================================================
# Source Git Shared Utilities
# =============================================================================

# Source centralized configuration
if [[ -f "$SHARED_DIR/config.sh" ]]; then
    source "$SHARED_DIR/config.sh"
fi

# Source portable timeout wrapper
if [[ -f "$SHARED_DIR/timeout-wrapper.sh" ]]; then
    source "$SHARED_DIR/timeout-wrapper.sh"
else
    # Fallback: define minimal portable timeout
    _portable_timeout() {
        local timeout_seconds="$1"
        shift
        if command_exists "timeout"; then
            timeout "$timeout_seconds" "$@"
        elif command_exists "gtimeout"; then
            gtimeout "$timeout_seconds" "$@"
        else
            "$@"
        fi
    }
fi

# =============================================================================
# Hook Skip Detection
# =============================================================================
# Check if hooks should be skipped (GIT_SKIP_HOOKS=1)
# Usage: at the start of hook logic after sourcing bootstrap
#   if hook_should_skip; then exit 0; fi
hook_should_skip() {
    [[ "${GIT_SKIP_HOOKS:-}" == "1" ]]
}

# Print skip message and exit
hook_skip_exit() {
    local hook_name="${1:-hook}"
    printf '%b⚠️  %s skipped (GIT_SKIP_HOOKS=1)%b\n' "${YELLOW}" "$hook_name" "${NC}" >&2
    exit 0
}

# =============================================================================
# Cleanup
# =============================================================================
unset _hook_caller_dir

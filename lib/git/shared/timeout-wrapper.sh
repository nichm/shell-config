#!/usr/bin/env bash
# =============================================================================
# ⏱️ PORTABLE TIMEOUT WRAPPER
# =============================================================================
# Provides cross-platform timeout functionality for git hooks.
# Works on both Linux (timeout) and macOS (gtimeout from coreutils).
# Usage:
#   source "${HOOKS_DIR}/shared/timeout-wrapper.sh"
#   _portable_timeout 60 some_command arg1 arg2
# =============================================================================
set -euo pipefail

# Source command cache for command_exists (needed when sourced from validation-loop)
# When sourced from hook-bootstrap, command-cache is already loaded
if ! declare -f command_exists &>/dev/null; then
    # shellcheck source=../../core/command-cache.sh
    if [[ -f "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/command-cache.sh" ]]; then
        source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/command-cache.sh"
    else
        command_exists() { command -v "$1" >/dev/null 2>&1; }
    fi
fi

# Portable timeout function that works on Linux and macOS
# Args:
#   $1 - Timeout in seconds
#   $@ - Command and arguments to run
# Returns:
#   Exit code of the command, or 124 on timeout (matching GNU timeout behavior)
_portable_timeout() {
    local timeout_seconds="$1"
    shift

    # Try native timeout (Linux/GNU), gtimeout (macOS with coreutils), or fallback
    if command_exists "timeout"; then
        timeout "$timeout_seconds" "$@"
    elif command_exists "gtimeout"; then
        gtimeout "$timeout_seconds" "$@"
    else
        # Fallback: run without timeout (less safe but functional)
        if [[ -n "${GIT_HOOKS_DEBUG:-}" ]]; then
            echo "⚠️  Timeout unavailable - command may run indefinitely" >&2
        fi
        "$@"
    fi
}

# Check if timeout capability is available
_has_timeout_capability() {
    command_exists "timeout" || command_exists "gtimeout"
}

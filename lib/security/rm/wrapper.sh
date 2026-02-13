#!/usr/bin/env bash
# =============================================================================
# rm/wrapper.sh - rm bypass protection for interactive shells
# =============================================================================
# Blocks direct calls to rm in interactive shells by using a function
# override that delegates to lib/bin/rm for protected paths.
# Note: Function is named 'rm' (not '/bin/rm') because bash function names
# cannot contain slashes. This function intercepts 'rm' commands and provides
# protection for critical paths. Direct '/bin/rm' bypasses this function.
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/security/rm/wrapper.sh"
# =============================================================================

# Prevent double-sourcing
[[ -n "${_SECURITY_RM_WRAPPER_LOADED:-}" ]] && return 0
_SECURITY_RM_WRAPPER_LOADED=1

# Block access helper
_rm_block_access() {
    local target="$1"
    local message_type="$2"
    shift 2 # Remove first two args, keep remaining for bypass command

    case "$message_type" in
        "protected-path")
            printf '🔴 ERROR: Protected path: %s\n' "$target" >&2
            printf '   WHY: This path is protected to prevent accidental data loss or system instability.\n' >&2
            printf '   FIX: Use unprotect-file first or trash-rm instead.\n' >&2
            ;;
        "config-file")
            printf '🔴 ERROR: Protected config file: %s\n' "$target" >&2
            printf '   WHY: Deleting this file can break application or shell configuration.\n' >&2
            printf '   FIX: Use unprotect-file first or trash-rm instead.\n' >&2
            ;;
        "system-path")
            printf '🔴 ERROR: System path: %s\n' "$target" >&2
            printf '   WHY: Deleting system paths can render your OS unusable.\n' >&2
            printf '   FIX: Use /bin/rm directly if absolutely certain: command /bin/rm' >&2
            printf ' %q' "$@" >&2
            printf '\n' >&2
            ;;
        "macos-system-path")
            printf '🔴 ERROR: macOS system path: %s\n' "$target" >&2
            printf '   WHY: Deleting macOS system paths can render your OS unusable.\n' >&2
            printf '   FIX: Use /bin/rm directly if absolutely certain: command /bin/rm' >&2
            printf ' %q' "$@" >&2
            printf '\n' >&2
            ;;
    esac

    # Show bypass instructions (except for system paths which already show it above)
    if [[ "$message_type" != "system-path" && "$message_type" != "macos-system-path" ]]; then
        printf '   Bypass: command /bin/rm' >&2
        printf ' %q' "$@" >&2
        printf '\n' >&2
    fi

    if [[ "$RM_AUDIT_ENABLED" == 1 ]]; then
        {
            printf '%(%F %T)T BLOCKED: /bin/rm' -1
            printf ' %q' "$@"
            printf '\n'
        } >>"$RM_AUDIT_LOG" 2>/dev/null &
    fi
}

# rm bypass protection (AI agent safety)
if [[ -f "$SHELL_CONFIG_DIR/lib/bin/rm" ]]; then
    # Source shared protected paths module
    source "${SHELL_CONFIG_DIR}/lib/core/protected-paths.sh"

    # Function override - catches rm in interactive shells
    # Scripts bypass this automatically (functions don't execute in non-interactive shells)
    # Note: Direct '/bin/rm' calls bypass this function intentionally for emergency access
    rm() {
        # Check if any arguments are protected paths
        for arg in "$@"; do
            # Skip flags
            [[ "$arg" == -* ]] && continue

            # Use merged get_protected_path_type function (returns both status and message type)
            if message_type=$(get_protected_path_type "$arg"); then
                _rm_block_access "$arg" "$message_type" "$@"
                return 1
            fi
        done

        # Not blocked - execute via our wrapper
        "$SHELL_CONFIG_DIR/lib/bin/rm" "$@"
    }

    # Note: No alias needed - function override takes precedence in shell lookup
fi

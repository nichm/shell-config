#!/usr/bin/env bash
# =============================================================================
# trash.sh - Trash integration and safe deletion helpers
# =============================================================================
# Provides trash-based deletion helpers without interactive prompts.
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/security/trash/trash.sh"
# =============================================================================

# Prevent double-sourcing
[[ -n "${_SECURITY_TRASH_LOADED:-}" ]] && return 0
_SECURITY_TRASH_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Check if trash command is available
_trash_ok() { command_exists "trash"; }

# Move files to trash instead of permanent deletion
trash-rm() {
    _trash_ok && {
        printf '🗑️  Trash: %s\n' "$*" >&2
        trash "$@"
    } || {
        echo "❌ ERROR: trash not installed" >&2
        echo "ℹ️  WHY: Safe deletion requires the trash utility" >&2
        echo "💡 FIX: brew install trash" >&2
        return 1
    }
}
alias trm='trash-rm'

# List files in trash
trash-list() {
    _trash_ok || {
        echo "❌ ERROR: trash not installed" >&2
        echo "ℹ️  WHY: Cannot list trash contents without the tool" >&2
        echo "💡 FIX: brew install trash" >&2
        return 1
    }
    trash -l
}

# Empty the trash (non-interactive; requires --force)
trash-empty() {
    if [[ "${1:-}" != "--force" ]]; then
        echo "❌ ERROR: Refusing to empty trash without --force" >&2
        echo "ℹ️  WHY: Destructive action must be explicit and non-interactive" >&2
        echo "💡 FIX: Run 'trash-empty --force'" >&2
        return 1
    fi

    _trash_ok || {
        echo "❌ ERROR: trash not installed" >&2
        echo "ℹ️  WHY: Cannot empty trash without the tool" >&2
        echo "💡 FIX: brew install trash" >&2
        return 1
    }

    trash -e && printf '✅ Done\n' >&2
}

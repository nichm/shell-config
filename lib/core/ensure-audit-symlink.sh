#!/usr/bin/env bash
# =============================================================================
# ensure-audit-symlink.sh - Audit log symlink management
# =============================================================================
# Creates and maintains a symlink from the repository to the audit log
# for easy access. The symlink points from shell-config/logs/audit.log
# to ~/.shell-config-audit.log. Ensures the symlink exists and is correct
# every time the shell initializes.
# Dependencies:
#   - None (works with standard bash/zsh)
# Environment Variables:
#   SHELL_CONFIG_DIR - Shell config installation directory
# Files:
#   Creates: shell-config/logs/audit.log → ~/.shell-config-audit.log
# Behavior:
#   - Checks if symlink exists and points to correct target
#   - Creates symlink if missing
#   - Repairs symlink if pointing to wrong target
#   - Silently succeeds if cannot determine directory
# Usage:
#   Source this file from shell init - runs automatically
#   Symlink created/verified on each shell startup
# =============================================================================

# Get script directory (zsh/bash compatible)
if [[ -n "${ZSH_VERSION:-}" ]]; then
    _AUDIT_SCRIPT_DIR="${0:A:h}"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    _AUDIT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _AUDIT_SCRIPT_DIR="$SHELL_CONFIG_DIR/lib/core"
else
    # Cannot determine directory, skip silently
    return 0 2>/dev/null || exit 0
fi

_AUDIT_REPO_ROOT="$(cd "$_AUDIT_SCRIPT_DIR/../.." && pwd)"
_AUDIT_SYMLINK_DIR="$_AUDIT_REPO_ROOT/logs"
_AUDIT_SYMLINK_PATH="$_AUDIT_SYMLINK_DIR/audit.log"
_AUDIT_TARGET_PATH="$HOME/.shell-config-audit.log"

# Check if symlink already exists and points to the correct target
if [[ -L "$_AUDIT_SYMLINK_PATH" ]]; then
    _AUDIT_CURRENT_TARGET=$(readlink "$_AUDIT_SYMLINK_PATH" 2>/dev/null || true)
    if [[ "$_AUDIT_CURRENT_TARGET" == "$_AUDIT_TARGET_PATH" ]]; then
        # Symlink exists and is correct, nothing to do
        unset _AUDIT_SCRIPT_DIR _AUDIT_REPO_ROOT _AUDIT_SYMLINK_DIR _AUDIT_SYMLINK_PATH _AUDIT_TARGET_PATH _AUDIT_CURRENT_TARGET
        return 0 2>/dev/null || exit 0
    fi
    # Symlink exists but points to wrong target, remove it
    command rm "$_AUDIT_SYMLINK_PATH" 2>/dev/null || true
elif [[ -f "$_AUDIT_SYMLINK_PATH" ]]; then
    # Regular file exists, don't overwrite
    unset _AUDIT_SCRIPT_DIR _AUDIT_REPO_ROOT _AUDIT_SYMLINK_DIR _AUDIT_SYMLINK_PATH _AUDIT_TARGET_PATH
    return 0 2>/dev/null || exit 0
fi

# Create logs directory if it doesn't exist
if [[ ! -d "$_AUDIT_SYMLINK_DIR" ]]; then
    mkdir -p "$_AUDIT_SYMLINK_DIR" 2>/dev/null || {
        unset _AUDIT_SCRIPT_DIR _AUDIT_REPO_ROOT _AUDIT_SYMLINK_DIR _AUDIT_SYMLINK_PATH _AUDIT_TARGET_PATH
        return 0 2>/dev/null || exit 0
    }
fi

# Create symlink (show message on first creation in new terminal session)
if ln -s "$_AUDIT_TARGET_PATH" "$_AUDIT_SYMLINK_PATH" 2>/dev/null; then
    # Only show message if this is a new setup (not every shell startup)
    if [[ -z "${_AUDIT_SYMLINK_CREATED:-}" ]]; then
        export _AUDIT_SYMLINK_CREATED=1
        echo ""
        echo "🔗 Created symlink: $_AUDIT_SYMLINK_PATH -> $_AUDIT_TARGET_PATH"
        echo ""
        echo "You can now view the audit log easily from the repository:"
        echo "  cat shell-config/logs/audit.log"
        echo "  tail -20 shell-config/logs/audit.log"
        echo ""
    fi
fi

# Cleanup temp variables
unset _AUDIT_SCRIPT_DIR _AUDIT_REPO_ROOT _AUDIT_SYMLINK_DIR _AUDIT_SYMLINK_PATH _AUDIT_TARGET_PATH _AUDIT_CURRENT_TARGET
